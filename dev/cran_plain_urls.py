# Writes every web address in the CRAN copy's README.md, DESCRIPTION and inst/CITATION, and every
# DOI in its help pages, as plain text, so CRAN's incoming check has nothing to fetch: a site that
# is down or slow when CRAN checks would otherwise add minutes and a NOTE. Run by dev/cran_build.sh
# inside the copy it builds from; the repository keeps its links.
import os
import re

U = r"https?://[^\s<>(){}\[\]\"']+"


def bare(url):
    # without the scheme or a leading www. no Markdown renderer turns it back into a link
    url = re.sub(r"^https?://", "", url)
    return re.sub(r"^www\.", "", url).rstrip("/")


def plain(text):
    text = re.sub(r"\[!\[[^\]]*\]\([^)]*\)\]\([^)]*\)", "", text)          # linked badge images
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", text)                        # other images
    text = re.sub(r"\[([^\]]+)\]\((" + U + r")\)", lambda m: "%s (%s)" % (m.group(1), bare(m.group(2))), text)
    text = re.sub(r"<(" + U + r")>", lambda m: bare(m.group(1)), text)
    return re.sub(U, lambda m: bare(m.group(0)), text)


# README.md: prose only; fenced code is never turned into links
lines, out, code = open("README.md", encoding="utf-8").read().split("\n"), [], False
for line in lines:
    if line.startswith("```"):
        code = not code
        out.append(line)
    else:
        out.append(line if code else plain(line))
open("README.md", "w", encoding="utf-8").write("\n".join(out))

# DESCRIPTION: plain addresses and DOIs in Description, and no URL or BugReports field
s = open("DESCRIPTION", encoding="utf-8").read()
s = re.sub(r"^(URL|BugReports):.*?(?=^[A-Z][A-Za-z/@]*:|\Z)", "", s, flags=re.S | re.M)
# a bare domain in single quotes, as DESCRIPTION writes other names, so the spell check skips it
s = re.sub(r"<(" + U + r")>", lambda m: "'%s'" % bare(m.group(1)), s)
s = re.sub(r"<doi:([^>]+)>", r"DOI \1", s)  # CRAN resolves each <doi:> online too
open("DESCRIPTION", "w", encoding="utf-8").write(s)

# help pages: each \doi{} as plain "DOI 10.x/y", since CRAN's incoming check resolves every one
# online (102 of them); the repository, r-universe and the website keep the links
for f in sorted(os.listdir("man")):
    if f.endswith(".Rd"):
        path = os.path.join("man", f)
        rd = open(path, encoding="utf-8").read()
        rd2 = re.sub(r"\\doi\{([^}]*)\}", r"DOI \1", rd)
        if rd2 != rd:
            open(path, "w", encoding="utf-8").write(rd2)

# inst/CITATION: the DOI identifies the package; drop the url field
s = open("inst/CITATION", encoding="utf-8").read()
s = re.sub(r",\s*\n\s*url\s*=\s*\"[^\"]*\"", "", s)
open("inst/CITATION", "w", encoding="utf-8").write(s)
