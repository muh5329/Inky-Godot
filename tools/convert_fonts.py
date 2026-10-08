"""Optional rebuild step: pip install fonttools brotli, then run this script."""
from pathlib import Path
from fontTools.ttLib import TTFont
root=Path(__file__).resolve().parents[1]
for source,target in [('TitanOne-latin.woff2','display.ttf'),('Rubik-latin.woff2','body.ttf')]:
    font=TTFont(root/'source_reference/assets/fonts'/source)
    font.flavor=None
    font.save(root/'assets/fonts'/target)
