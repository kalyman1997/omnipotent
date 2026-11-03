"""Protocol tests with a fake game directory, never the running game."""
import json
from pathlib import Path
import tempfile
import time
import unittest
from controller import BO7TrainerController, PROTOCOL, FLAGS
from channel_lock import ChannelLock


class ChannelTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.c = BO7TrainerController(self.tmp.name)
        self.c.session = "testsession"
        self.c.running = True
        self.c.status_path.parent.mkdir(parents=True)
        self.c._write_command()

    def tearDown(self):
        self.c.disconnect()
        self.tmp.cleanup()

    def ack(self, **changes):
        values = dict(protocol=PROTOCOL, session=self.c.session, lease=self.c.lease,
                      revision=self.c.revision, ready=1, players=1, ammo=0,
                      no_reload=0, godmode=0, clip=30, stock=139, tick=10)
        values.update({key: 0 for key in FLAGS})
        values.update(changes)
        self.c.status_path.write_text(json.dumps(dict(values=values)))
        self.c._read_ack()
        return self.c.status()

    def test_requires_ack_for_requested_option(self):
        self.c.set_option("ammo", True)
        self.assertFalse(self.c.status()["options"]["ammo"]["enabled"])
        self.assertTrue(self.ack(ammo=1)["options"]["ammo"]["enabled"])

    def test_jetpack_requires_ack_and_disconnect_stops_thrust_request(self):
        self.c.set_option("jetpack", True)
        self.c.set_numeric("jetpack", 9000)
        sent = json.loads(self.c.command_path.read_text())["values"]
        self.assertEqual((sent["jetpack"], sent["jetpack_value"]), (1, 80000))
        self.assertFalse(self.c.status()["options"]["jetpack"]["enabled"])
        self.assertTrue(self.ack(jetpack=1, jetpack_available=1)["options"]["jetpack"]["enabled"])
        self.c.disconnect()
        self.assertEqual(json.loads(self.c.command_path.read_text())["values"]["jetpack"], 0)

    def test_old_protocol_cannot_confirm_jetpack(self):
        self.c.set_option("jetpack", True)
        state = self.ack(protocol=4, jetpack=1)
        self.assertFalse(state["options"]["jetpack"]["enabled"])
        self.assertTrue(self.c.protocol_mismatch)

    def test_rejects_previous_session_and_revision(self):
        self.c.set_option("ammo", True)
        self.assertFalse(self.ack(session="previous", ammo=1)["connected"])
        self.assertFalse(self.ack(revision=0, ammo=1)["connected"])

    def test_stale_ack_does_not_confirm(self):
        self.c.set_option("ammo", True)
        self.ack(ammo=1)
        self.c.last_ack_time = time.monotonic() - 10
        self.assertFalse(self.c.status()["options"]["ammo"]["enabled"])

    def test_multiplayer_guard_and_malformed_ack(self):
        self.c.set_option("ammo", True)
        self.assertFalse(self.ack(players=2, ammo=1)["options"]["ammo"]["enabled"])
        self.c.status_path.write_text('{"values":')
        self.c._read_ack()
        self.assertFalse(self.c.status()["options"]["ammo"]["enabled"])

    def test_disconnect_writes_off_and_new_lease(self):
        self.c.set_option("ammo", True)
        old = self.c.lease
        self.c.disconnect()
        command = json.loads(self.c.command_path.read_text())["values"]
        self.assertEqual(command["ammo"], 0)
        self.assertGreater(command["lease"], old)
        self.assertFalse(self.c.status()["running"])

    def test_unsupported_never_enabled(self):
        self.assertFalse(self.c.set_option("not_an_option", True))

    def test_points_once_ack_and_next_nonce(self):
        self.ack()
        self.assertTrue(self.c.set_option("points", True))
        nonce = self.c.points_nonce
        self.assertEqual(nonce, 1)
        state = self.ack(points_nonce=nonce, points_result="applied", essence=10500)
        self.assertFalse(state["options"]["points"]["requested"])
        self.assertEqual(state["options"]["points"]["state"], "applied")
        self.c._write_command()
        self.assertEqual(self.c.points_nonce, nonce)
        self.c.set_option("points", True)
        self.assertEqual(self.c.points_nonce, nonce + 1)

    def test_points_requires_ready_and_caps_amount(self):
        self.assertFalse(self.c.set_option("points", True))
        self.c.set_numeric("points", 999999999)
        self.assertEqual(self.c.options["points"]["value"], 999999)

    def test_god_requires_confirmed_ack(self):
        self.c.set_option("godmode", True)
        self.assertFalse(self.c.status()["options"]["godmode"]["enabled"])
        self.assertTrue(self.ack(godmode=1)["options"]["godmode"]["enabled"])

    def test_pending_points_amount_is_immutable_and_not_repeated(self):
        self.ack()
        self.c.set_option("points", True)
        self.c.set_numeric("points", 30000)
        self.assertFalse(self.c.set_option("points", True))
        self.c._write_command()
        sent = json.loads(self.c.command_path.read_text())["values"]
        self.assertEqual((sent["points_amount"], sent["points_nonce"]), (10000, 1))
        self.ack(points_nonce=1, points_result="applied")
        self.assertTrue(self.c.set_option("points", True))
        sent = json.loads(self.c.command_path.read_text())["values"]
        self.assertEqual((sent["points_amount"], sent["points_nonce"]), (30000, 2))

    def test_rejects_nonfinite_numeric_input(self):
        for value in (float("nan"), float("inf"), float("-inf")):
            self.assertFalse(self.c.set_numeric("points", value))
        self.assertEqual(self.c.options["points"]["value"], 10000)

    def test_writer_lock_rejects_second_owner_then_releases(self):
        path = Path(self.tmp.name) / "writer.lock"
        first, second = ChannelLock(path), ChannelLock(path)
        self.assertTrue(first.acquire())
        try:
            self.assertFalse(second.acquire())
        finally:
            first.release()
        self.assertTrue(second.acquire())
        second.release()

    def test_unavailable_god_is_not_left_pending(self):
        self.c.set_option("godmode", True)
        status = self.ack(god_available=0)
        self.assertEqual(status["options"]["godmode"]["state"], "unavailable")
        self.assertFalse(status["options"]["godmode"]["enabled"])

    def test_numeric_damage_protocol_and_exclusive_modes(self):
        self.c.set_option("damage", True)
        self.c.set_numeric("damage_multiplier", 3.5)
        self.c.set_option("damage_multiplier", True)
        sent = json.loads(self.c.command_path.read_text())["values"]
        self.assertEqual(sent["damage_multiplier_value"], 350)
        self.assertEqual((sent["damage"], sent["damage_multiplier"]), (0, 1))
        self.c.set_option("damage", True)
        sent = json.loads(self.c.command_path.read_text())["values"]
        self.assertEqual((sent["damage"], sent["damage_multiplier"]), (1, 0))

    def test_missing_option_ack_rejected(self):
        self.c.set_option("equipment", True)
        self.ack(equipment=None)
        self.assertFalse(self.c.connected)

    def test_old_protocol_rejected(self):
        self.ack(protocol=PROTOCOL-1)
        self.assertTrue(self.c.protocol_mismatch)
        self.assertFalse(self.c.connected)


if __name__ == "__main__":
    unittest.main()
