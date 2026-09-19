// Locality: server, [] call'd at load. The action list the pick stage (fnc_opcom_pick) draws from.
// DUWS_opcom_actions row: [id, class, targets, execute].
//   call targets -> [[target, price, label], ...], the action's legal targets now. Runs inside isNil, so it never suspends.
//   [target, price] call execute -> true when the action landed; the pick charges the price only then.
if (!isServer) exitWith {};

DUWS_opcom_aiMode = "off";
DUWS_opcom_pickOnce = false;

DUWS_opcom_actions = [
    ["bank", "bank", { [[[], 0, "Bank"]] }, { true }]
];
