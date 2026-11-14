from pathlib import Path
from zipfile import ZipFile
root=Path(__file__).resolve().parents[1]
# Existing unpacked files are editable project assets; never overwrite replacements.
with ZipFile(root/'art/japan_assets.zip') as z:
    assert z.testzip() is None
    for name in z.namelist():
        target=(root/name).resolve()
        assert target.is_relative_to(root.resolve()) and (name.startswith('art/japan/') or name=='data/character_assets.json')
        if not target.exists():
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(z.read(name))
print('Japanese asset bundle ready (existing overrides preserved)')
