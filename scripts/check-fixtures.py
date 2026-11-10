"""Verify upstream fixture integrity and keep answer keys out of questions."""
import hashlib
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'contracts/fixture-provenance.json').read_text())
actual = {p.name for p in (root / 'assets/fixtures').glob('*.json')}
assert actual == set(manifest['sha256']), 'Fixture inventory changed without provenance'
for name, digest in manifest['sha256'].items():
    path = root / 'assets/fixtures' / name
    assert hashlib.sha256(path.read_bytes()).hexdigest() == digest, name
    fixture = json.loads(path.read_text())
    assert fixture['valid'], name
    assert fixture['operation_id'] != 'deliverResult', 'Internal worker data must not ship to learners'
    instance = fixture['response']['body'].get('current_instance')
    if instance:
        question = instance['question']
        assert not {'assessment', 'correct_option_id', 'correct_order', 'accepted_commands', 'hints'} & question.keys(), name
print(f"Verified {len(actual)} unchanged public API fixtures")
