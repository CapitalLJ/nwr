{%- include "header" -%}
{# Keep a blank line #}
#----------------------------#
# Run
#----------------------------#
log_warn rank.sh

{% for rank in count_ranks -%}
log_info "Count {{ rank }}"

log_debug "{{ rank }}.lst"
cat strains.taxon.tsv |
    tsv-select -f {{ rank_col_of[rank] }} |
    tsv-uniq |
    grep -v "NA" |
    sort \
    > {{ rank }}.lst

log_debug "{{ rank }}.count.tsv"
cat {{ rank }}.lst |
    parallel --no-run-if-empty --linebuffer -k -j 4 '
        n_species=$(
            cat strains.taxon.tsv |
                tsv-filter --str-eq "{{ rank_col_of[rank] }}:{}" |
                tsv-select -f {{ rank_col_of[rank] }},3 |
                tsv-uniq |
                wc -l
        )

        n_strains=$(
            cat strains.taxon.tsv |
                tsv-filter --str-eq "{{ rank_col_of[rank] }}:{}" |
                tsv-select -f {{ rank_col_of[rank] }},1 |
                tsv-uniq |
                wc -l
        )

        printf "%s\t%d\t%d\n" {} ${n_species} ${n_strains}
    '
{% endfor -%}
{# Keep a blank line #}
log_info Done.

exit 0
