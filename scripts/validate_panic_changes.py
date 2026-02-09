#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
client = (ROOT / 'client' / 'client.lua').read_text()
server = (ROOT / 'server' / 'server.lua').read_text()
config = (ROOT / 'config.lua').read_text()

checks = []

def check(name, cond):
    checks.append((name, bool(cond)))

check('client registers panicSent event', "RegisterNetEvent('gps_tracker:panicSent'" in client)
check('client registers panicDenied event', "RegisterNetEvent('gps_tracker:panicDenied'" in client)
check('client receive panic plays sound', re.search(r"gps_tracker:receivePanic'.*?PlayPanicSound\(\)", client, re.S))
use_panic_match = re.search(r"local function UsePanic\(\)(.*?)end\n\n", client, re.S)
check('client UsePanic block found', use_panic_match is not None)
use_panic_block = use_panic_match.group(1) if use_panic_match else ''
check('client does not optimistic panic_sent in UsePanic', "ShowNotification('panic_sent')" not in use_panic_block)

check('server denies panic when cuffed', "TriggerClientEvent('gps_tracker:panicDenied', playerId, 'cannot_use_cuffed')" in server)
check('server enforces cooldown', "sender.panicLastAt" in server and "panic_cooldown" in server)
check('server sends panicSent ack', "TriggerClientEvent('gps_tracker:panicSent', playerId" in server)
check('server supports nearby audible radius', 'nearbyAudibleRadius' in server)

check('config has panic_failed notification', "['panic_failed']" in config)
check('config has panic sound block', 'audioName' in config and 'audioRef' in config)

failed = [name for name, ok in checks if not ok]
if failed:
    print('Validation failed:')
    for name in failed:
        print(f' - {name}')
    raise SystemExit(1)

print(f'Validation passed ({len(checks)} checks).')
