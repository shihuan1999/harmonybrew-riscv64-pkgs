NAME="perl"
VERSION="5.40.0"
URL="https://www.cpan.org/src/5.0/perl-5.40.0.tar.gz"
DESC="Perl: scripting language (bioinformatics pipelines)"
BUILD_METHOD="custom"
CUSTOM_BUILD='./Configure -des -Dprefix="$stage" -Duseshrplib=false -Dman1dir=none -Dman3dir=none'
INSTALL_CMD='make -j"$HBREW_JOBS" && make install'
