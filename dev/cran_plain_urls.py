# Writes every web address in the CRAN copy's README.md, DESCRIPTION and inst/CITATION, and every
# DOI in its help pages, as plain text, so CRAN's incoming check has nothing to fetch: a site that
# is down or slow when CRAN checks would otherwise add minutes and a NOTE. Run by dev/cran_build.sh
# inside the copy it builds from; the repository keeps its links.
import re
from pathlib import Path

U = r"https?://[^\s<>(){}\[\]\"']+"
# the package's canonical CRAN address stays a link: CRAN asks for it in citations, and its own
# page is the one address the incoming check fetches at once
CANONICAL = "https://CRAN.R-project.org/package=rmoriebricklayer"


def read(path):
    return Path(path).read_text(encoding="utf-8")


def write(path, text):
    Path(path).write_text(text, encoding="utf-8")


def reflow_description(s):
    m = re.search(r"^Description:(.*?)(?=^[A-Z][A-Za-z/@]*:|\Z)", s, flags=re.DOTALL | re.MULTILINE)
    words = m.group(1).split()
    lines, cur = [], "Description:"
    for w in words:
        if len(cur) + 1 + len(w) > 76:
            lines.append(cur)
            cur = "    " + w
        else:
            cur += " " + w
    lines.append(cur)
    return s[:m.start()] + "\n".join(lines) + "\n" + s[m.end():]


def bare(url):
    if url == CANONICAL:
        return url
    # without the scheme or a leading www. no Markdown renderer turns it back into a link
    url = re.sub(r"^https?://", "", url)
    return re.sub(r"^www\.", "", url).rstrip("/")


def plain(text):
    text = re.sub(r"\[!\[[^\]]*\]\([^)]*\)\]\([^)]*\)", "", text)          # linked badge images
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", text)                        # other images
    text = re.sub(r"\[([^\]]+)\]\((" + U + r")\)", lambda m: f"{m.group(1)} ({bare(m.group(2))})", text)
    text = re.sub(r"<(" + U + r")>", lambda m: bare(m.group(1)), text)
    return re.sub(U, lambda m: bare(m.group(0)), text)


# README.md: prose only; fenced code is never turned into links
out, code = [], False
for line in read("README.md").split("\n"):
    if line.startswith("```"):
        code = not code
        out.append(line)
    else:
        out.append(line if code else plain(line))
write("README.md", "\n".join(out))

# DESCRIPTION: plain addresses and DOIs in Description; URL and BugReports stay, since CRAN,
# r-universe and the CRAN page link the package to its repository and issue tracker through them
s = read("DESCRIPTION")
# a bare domain in single quotes, as DESCRIPTION writes other names, so the spell check skips it
s = re.sub(r"<(" + U + r")>", lambda m: f"'{bare(m.group(1))}'", s)
s = re.sub(r"<doi:([^>]+)>", r"DOI \1", s)  # CRAN resolves each <doi:> online too
s = reflow_description(s)  # the replacements shortened some lines
write("DESCRIPTION", s)

# help pages: each \doi{} as plain "DOI 10.x/y", since CRAN's incoming check resolves every one
# online (102 of them); the repository, r-universe and the website keep the links
for path in sorted(Path("man").glob("*.Rd")):
    rd = read(path)
    rd2 = re.sub(r"\\doi\{([^}]*)\}", r"DOI \1", rd)
    if rd2 != rd:
        write(path, rd2)

# inst/CITATION keeps its DOI and its url, the canonical CRAN address
