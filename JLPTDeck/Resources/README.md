## JLPTDeck bundled resources

`jmdict_n4_n1.json` lives here after running the build-time tool:

```
swift scripts/build_jmdict_bundle.swift \
  --jmdict    /path/to/JMdict_e.xml \
  --tanos-dir /path/to/tanos-lists/ \
  --out       JLPTDeck/Resources/jmdict_n4_n1.json
```

### Source attribution (required in the shipping app)

- **JMdict** © Electronic Dictionary Research and Development Group, licensed
  under CC BY-SA 3.0 — https://www.edrdg.org/jmdict/edict_doc.html
- **Tanos JLPT lists** by Jonathan Waller — https://www.tanos.co.uk/jlpt/

### Tanos list layout expected by the script

In `--tanos-dir` the script looks for:

```
n4-vocab-kanji.utf
n3-vocab-kanji.utf
n2-vocab-kanji.utf
n1-vocab-kanji.utf
```

Each file is UTF-8, one entry per line. When a headword appears in multiple
level lists, the lower (easier) level wins: n4 > n3 > n2 > n1.
