# The suite never reaches the user's real systemd manager: a check run by a
# test lists and stops no user units (42d41d4 recheck: systemctl --user was
# called 16 times under CRAN-mode tests). The fake-systemctl test passes its
# own program explicitly.
options(rmbl.bundle.systemd = FALSE)
