"""Seed corpora from the test fixtures: DER certificates and a timestamp token,
the synthetic SIU report, and a spread of decimal strings."""
import pathlib, re
here = pathlib.Path(__file__).parent
tt = here / "../../tests/testthat"
der = here / "corpus/der"; der.mkdir(parents=True, exist_ok=True)
for f in ["x509-fixtures.txt", "timestamp-token.txt"]:
    for line in (tt / f).read_text().splitlines():
        if line.startswith("#") or "|" not in line: continue
        name, hx = line.split("|", 1)
        hx = re.sub(r"[^0-9a-fA-F]", "", hx)
        if len(hx) % 2 == 0 and hx:
            (der / f"{name}.bin").write_bytes(b"\x01" + bytes.fromhex(hx))
(der / "rsa-slices.bin").write_bytes(b"\x00" + bytes(range(1, 97)))
siu = here / "corpus/siu"; siu.mkdir(parents=True, exist_ok=True)
html = (here / "../extdata/siu_synthetic_report.html").read_bytes()
(siu / "synthetic.html").write_bytes(html)
(siu / "synthetic.txt").write_bytes(re.sub(rb"<[^>]+>", b" ", html))
st = here / "corpus/strtod"; st.mkdir(parents=True, exist_ok=True)
for i, s in enumerate(["0", "1", "-1", "0.1", "1e308", "1e-308", "4.9406564584124654e-324", "2.2250738585072014e-308",
                       "9007199254740993", "0.30000000000000004", "123456789012345678901234567890", "1.7976931348623157e308",
                       "1e-400", "1e400", "-0.0", "3.14159265358979323846264338327950288", "5e-324", "2.4703282292062327e-324"]):
    (st / f"s{i}.txt").write_text(s)
print("corpus:", len(list(der.iterdir())), "der,", len(list(siu.iterdir())), "siu,", len(list(st.iterdir())), "strtod")
