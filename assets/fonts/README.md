# Fonts

These font files are **not** covered by the repository's all-rights-reserved licence. Each is
licensed under the SIL Open Font License 1.1; the licence text is next to the files.

| Family | Used for | Licence |
|---|---|---|
| Abhaya Libre | Headings (Latin and Sinhala) | `OFL-abhayalibre.txt` |
| Yaldevi | Body text (Latin and Sinhala) | `OFL-yaldevi.txt` |
| JetBrains Mono | Numbers and prices | `OFL-jetbrainsmono.txt` |
| Noto Sans Sinhala | Sinhala fallback | `OFL-notosanssinhala.txt` |
| Noto Sans Tamil | Tamil fallback | `OFL-notosanstamil.txt` |

They are the weights the website loads, from Google Fonts. Yaldevi is published only as a variable
font, which Flutter can't select weights from, so its four files are static instances cut with
fonttools: `fonttools varLib.instancer "Yaldevi[wght].ttf" wght=600 -o Yaldevi-SemiBold.ttf`.
