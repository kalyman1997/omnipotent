"""One-shot actions and bounded weapon catalog, with no running game."""
import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

from controller import BO7TrainerController, FLAGS, PROTOCOL
from weapons import AMMO_MOD_IDS


class WeaponActionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.c = BO7TrainerController(self.tmp.name)
        self.c.session = "current-session"
        self.c.running = True
        self.c.status_path.parent.mkdir(parents=True)
        self.c._write_command()
        self.ack()

    def tearDown(self):
        self.c.disconnect()
        self.tmp.cleanup()

    def ack(self, **changes):
        values = dict(protocol=PROTOCOL, session=self.c.session, lease=self.c.lease,
                      revision=self.c.revision, ready=1, players=1, tick=self.c.lease,
                      action_nonce=0, action_result="none", action_detail="")
        values.update({key: 0 for key in FLAGS})
        values.update(changes)
        self.c.status_path.write_text(json.dumps({"values": values}), encoding="utf-8")
        self.c._read_ack()
        return self.c.status()

    def command(self):
        return json.loads(self.c.command_path.read_text())["values"]

    def test_give_weapon_requires_solo_and_fresh_ready_snapshot(self):
        for changes in ({"ready": 0}, {"players": 2}):
            self.ack(**changes)
            self.assertFalse(self.c.weapon_action("give_weapon", "sat_ww_raygun_mp"))
        self.ack()
        self.c.last_ack_time = time.monotonic() - 10
        self.assertFalse(self.c.weapon_action("give_weapon", "sat_ww_raygun_mp"))
        self.assertEqual(self.c.action_nonce, 0)

    def test_bad_weapon_ids_never_enter_command_file(self):
        for value in ("../weapon", "weapon;exec", "a\nother", "a" * 97, None, [], 123):
            self.assertFalse(self.c.weapon_action("give_weapon", value), repr(value))
        self.assertEqual(self.command()["action_kind"], "")

    def test_pending_action_immutable_across_heartbeats(self):
        self.assertTrue(self.c.weapon_action("give_weapon", "SAT_WW_RAYGUN_MP"))
        initial = self.command()
        self.assertFalse(self.c.weapon_action("pap", level=3))
        self.c._write_command()
        new = self.command()
        for key in ("action_nonce", "action_kind", "action_value", "action_level"):
            self.assertEqual(new[key], initial[key])
        self.assertGreater(new["lease"], initial["lease"])
        self.assertEqual(new["action_value"], "sat_ww_raygun_mp")

    def test_only_matching_terminal_ack_completes_action(self):
        self.c.weapon_action("pap", level=3)
        for changes in ({"session": "old"}, {"revision": -1}, {"action_nonce": 100}):
            snapshot = dict(action_nonce=1, action_result="applied")
            snapshot.update(changes)
            self.assertEqual(self.ack(**snapshot)["action"]["state"], "pending")
        self.assertEqual(self.ack(action_nonce=1, action_result="pending")["action"]["state"], "pending")
        self.assertEqual(self.ack(action_nonce=1, action_result="applied")["action"]["state"], "applied")

    def test_terminal_rejection_allows_next_nonce(self):
        self.c.weapon_action("give_weapon", "missing_weapon")
        state = self.ack(action_nonce=1, action_result="unavailable", action_detail="unknown_weapon")
        self.assertEqual(state["action"]["state"], "unavailable")
        self.assertTrue(state["actions_ready"])
        self.assertTrue(self.c.weapon_action("pap", level=2))
        self.assertEqual(self.command()["action_nonce"], 2)

    def test_pap_levels_are_exact_targets_1_through_3(self):
        for invalid in (0, 4, -1, True, 2.0, "3"):
            self.assertFalse(self.c.weapon_action("pap", level=invalid))
        for valid in (1, 2, 3):
            self.assertTrue(self.c.weapon_action("pap", level=valid))
            self.assertEqual(self.command()["action_level"], valid)
            self.ack(action_nonce=self.c.action_nonce, action_result="applied", pap_level=valid)

    def test_end_round_is_one_shot_and_requires_matching_confirmation(self):
        self.assertTrue(self.c.weapon_action("end_round", "ignored", 99))
        first = self.command()
        self.assertEqual((first["action_kind"], first["action_value"], first["action_level"]), ("end_round", "", 0))
        self.assertFalse(self.c.weapon_action("end_round"))
        self.c._write_command()
        self.assertEqual(self.command()["action_nonce"], first["action_nonce"])
        self.assertEqual(self.ack(action_nonce=first["action_nonce"] + 1, action_result="applied")["action"]["state"], "pending")
        self.assertEqual(self.ack(action_nonce=first["action_nonce"], action_result="applied", action_detail="round_finished")["action"]["state"], "applied")

    def test_ammo_modes_allow_only_reviewed_native_ids(self):
        self.assertFalse(self.c.weapon_action("ammo_mod", "invented_power"))
        for value in sorted(AMMO_MOD_IDS):
            self.assertTrue(self.c.weapon_action("ammo_mod", value))
            self.assertEqual(self.command()["action_value"], value)
            self.ack(action_nonce=self.c.action_nonce, action_result="applied", ammo_mod=value)

    def test_disconnect_cancels_pending_without_new_action(self):
        self.c.weapon_action("pap", level=3)
        self.c.disconnect()
        command = self.command()
        self.assertEqual(command["action_nonce"], 0)
        self.assertEqual(command["action_kind"], "")
        self.assertEqual(self.c.action["state"], "cancelled")

    def test_reconnect_never_replays_previous_action(self):
        self.c.weapon_action("pap", level=3)
        previous_session = self.c.session
        self.c.disconnect()
        script = self.c.root / "kronos/custom_scripts/codex_solo_trainer.gsc"
        script.parent.mkdir(parents=True)
        script.write_text("fixture")
        with patch("controller.discover_root", return_value=(None, None)), patch("threading.Thread.start"):
            self.assertTrue(self.c.connect())
        self.c.monitor_thread = None
        command = self.command()
        self.assertNotEqual(command["session"], previous_session)
        self.assertEqual((command["action_nonce"], command["action_kind"]), (0, ""))

    def test_finished_action_is_not_replayed_when_game_resets_nonces(self):
        self.c.weapon_action("end_round")
        self.ack(action_nonce=1, action_result="applied", action_detail="round_finished")
        self.c._write_command()
        self.assertEqual((self.command()["action_nonce"], self.command()["action_kind"]), (0, ""))
        self.ack(action_nonce=0, action_result="none")
        self.assertEqual(self.c.action["state"], "applied")
        self.assertTrue(self.c.weapon_action("end_round"))
        self.assertEqual(self.command()["action_nonce"], 2)

    def test_failed_write_does_not_leave_phantom_pending_action(self):
        with patch.object(self.c, "_write_command", side_effect=OSError("disk unavailable")):
            self.assertFalse(self.c.weapon_action("pap", level=1))
        self.assertEqual(self.c.action["state"], "idle")
        self.assertEqual(self.c.action_nonce, 0)

    def catalog(self, **changes):
        path = self.c.root / "kronos/codexcatalog/catalog.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        data = dict(protocol=PROTOCOL, session=self.c.session, weapon_count=2,
                    weapon_0="sat_ww_raygun_mp", weapon_1="sat_ww_firefly_zm")
        data.update(changes)
        path.write_text(json.dumps({"values": data}), encoding="utf-8")
        self.c._read_catalog()
        return self.c.weapon_catalog

    def test_catalog_is_session_bound_validated_and_bounded(self):
        self.assertEqual(self.catalog(session="previous"), [])
        self.assertEqual(self.catalog(weapon_count=513), [])
        self.assertEqual(self.catalog(weapon_0="../invalid", weapon_1=None), [])
        self.assertEqual(len(self.catalog()), 2)
        self.assertEqual(len(self.catalog(weapon_count=999)), 2)

    def test_catalog_de_duplicates_names(self):
        self.assertEqual(self.catalog(weapon_1="sat_ww_raygun_mp"), ["sat_ww_raygun_mp"])

    def test_catalog_retains_valid_ids_among_unsupported_metadata_keys(self):
        self.assertEqual(self.catalog(weapon_count=4, weapon_1="map:key/unsupported",
                                     weapon_2="sat_ww_firefly_zm", weapon_3=None),
                         ["sat_ww_firefly_zm", "sat_ww_raygun_mp"])

    def test_malformed_ack_cannot_confirm_action(self):
        self.c.weapon_action("pap", level=1)
        for fields in ({"action_nonce": True}, {"players": True}, {"action_result": "unknown"}):
            values = dict(action_nonce=1, action_result="applied")
            values.update(fields)
            self.assertEqual(self.ack(**values)["action"]["state"], "pending")


if __name__ == "__main__":
    unittest.main()
