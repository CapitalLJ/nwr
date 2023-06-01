{%- include "header" -%}
{# Keep a blank line #}
#----------------------------#
# Run
#----------------------------#
log_warn reorder.sh

log_info "Put the misplaced directory in the right place"
find . -maxdepth 3 -mindepth 2 -type f -name "*_genomic.fna.gz" |
    grep -v "_from_" |
    parallel --no-run-if-empty --linebuffer -k -j 1 '
        echo {//}
    ' |
    tr "/" "\t" |
    perl -nla -F"\t" -MPath::Tiny -e '
        BEGIN {
            our %species_of = map {(split)[0, 2]}
                grep {/\S/}
                path(q{url.tsv})->lines({chomp => 1});
        }

        # Should like ".       Saccharomyces_cerevisiae        Sa_cer_S288C"
        @F != 3 and print and next;

        # Assembly is not in the list
        if (! exists $species_of{$F[2]} ) {
            print;
            next;
        }

        # species is the correct one
        if ($species_of{$F[2]} ne $F[1]) {
            print;
            next;
        }
    ' |
    perl -nla -F"\t" -e '
        m((GC[FA]_\d+_\d+$)) or next;
        my $acc = $1;
        my $dir = join q(/), @F;
        print join qq(\t), $dir, $acc;
    ' \
    > misplaced.tsv

cat misplaced.tsv |
    parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 1 '
        TARGET=$(
            tsv-filter url.tsv --str-in-fld "1:{2}" |
                tsv-select -f 3,1 |
                tr "\t" "/"
            )
        if [ -e ${TARGET} ]; then
            echo >&2 "${TARGET} exiests"
        else
            echo >&2 "Moving ${TARGET}"
            mv {1} "${TARGET}"
        fi
    '

log_info "Remove dirs (species) not in the list"
find . -maxdepth 1 -mindepth 1 -type d |
    tr "/" "\t" |
    tsv-select -f 2 |
    tsv-join --exclude -k 3 -f ./url.tsv -d 1 |
    xargs -I[] rm -fr "./[]"

log_info "Remove dirs (assemblies) not in the list"
cat ./url.tsv |
    tsv-select -f 3 |
    tsv-uniq |
while read SPECIES; do
    find "./${SPECIES}" -maxdepth 1 -mindepth 1 -type d |
        tr "/" "\t" |
        tsv-select -f 3 |
        tsv-join --exclude -k 1 -f ./url.tsv -d 1 |
        xargs -I[] rm -fr "./${SPECIES}/[]"
done

log_info "Temporary files, possibly caused by an interrupted rsync process"
find . -type f -name ".*" > temp.list

cat ./temp.list |
    parallel --no-run-if-empty --linebuffer -k -j 1 '
        if [[ -f {} ]]; then
            echo Remove {}
            rm {}
        fi
    '

log_info Done.

exit 0
