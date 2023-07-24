#!/usr/bin/bash

read -rp "file = " file
tput cuu1
tput el
chosen_color=(255 255 255)  # Default chosen color
read -rp "r = " chosen_r
tput cuu1
tput el
if [ "$chosen_r" != "" ]; then
    read -rp "g = " chosen_g
    tput cuu1
    tput el
    if [ "$chosen_g" != "" ]; then
        read -rp "b = " chosen_b
        tput cuu1
        tput el
        if [ "$chosen_b" != "" ]; then
            chosen_color=("$chosen_r" "$chosen_g" "$chosen_b")
        fi
    fi
fi

hex_strings=($(grep -Eo "#[a-fA-F0-9]{6}" "$file" | sort | uniq))
rgb_strings=($(grep -Eo "rgba?\( *[0-9]+ *, *[0-9]+ *, *[0-9]+ *,? *[0-9]*\.?[0-9]* *)" "$file" | sort | uniq | grep -Eo "[0-9]*|)"))

formatted_strings=()  # The list to which all formatted color strings(with percentages, etc.) will be appended. That'll be the output.

function similarity_calc(){
    n_of_vals=$(( $1 - $2 ))
    n_of_vals=$(( ${n_of_vals#-} + 1 ))
    added_vals=$( echo "$n_of_vals * (($1 + $2) / 2)" | bc -l )
    if [ "$3" = higher ]; then
        added_vals=$( echo "$n_of_vals * 255 - $added_vals" | bc -l )
    fi
    pre_perc_return=$( echo "(50 * ($added_vals / $n_of_vals ) / 127.5 + 50) * $n_of_vals" | bc -l )
    echo "$pre_perc_return"
}

# The 3 parameters are the 'r', 'g' and 'b' values of the given color.
function similarity(){
    parameters=("$1" "$2" "$3")
    pre_perc=0
    for i in {0..2}; do        
        if [ "${chosen_color[$i]}" -gt 127 ] && [ "${parameters[$i]}" -gt 127 ]; then
            pre_perc=$( echo "$pre_perc + $(similarity_calc "${chosen_color[$i]}" "${parameters[$i]}" higher)" | bc -l )
        elif [ "${chosen_color[$i]}" -lt 128 ] && [ "${parameters[$i]}" -lt 128 ]; then
            pre_perc=$( echo "$pre_perc + $(similarity_calc "${chosen_color[$i]}" "${parameters[$i]}" lower)" | bc -l )
        elif [ "${chosen_color[$i]}" -gt 127 ] && [ "${parameters[$i]}" -lt 128 ]; then
            pre_perc=$( echo "$pre_perc + $(similarity_calc "${chosen_color[$i]}" 128 higher)" | bc -l )
            pre_perc=$( echo "$pre_perc + $(similarity_calc "${parameters[$i]}" 127 lower)" | bc -l )
        else
            pre_perc=$( echo "$pre_perc + $(similarity_calc "${parameters[$i]}" 128 higher)" | bc -l )
            pre_perc=$( echo "$pre_perc + $(similarity_calc "${chosen_color[$i]}" 127 lower)" | bc -l )
        fi
    done
    perc=$( echo "100 - $pre_perc * 100 / 57374.70588235294" | bc -l )
    formatted_perc=${perc//./,}
    formatted_perc=$(printf "%.*f\n" "0" "$formatted_perc")
    formatted_perc=$(echo "$formatted_perc" | tr -d -c 0-9)
    formatted_perc="$formatted_perc%"
    if [ ${#formatted_perc} = 3 ]; then
        formatted_perc="$formatted_perc "
    elif [ ${#formatted_perc} = 2 ]; then
        formatted_perc="$formatted_perc  "
    fi
    echo "$formatted_perc"
}


function format_to_rgb(){
    formatted_rgb_string="rgb($1, $2, $3)"
    echo "$formatted_rgb_string"
}

# Addressing the file's hex color codes:
for hex_string in "${hex_strings[@]}"; do
    formatted_hex_string=$(echo "$hex_string" | tr '[:lower:]' '[:upper:]')
    r="$((16#${formatted_hex_string:1:2}))"
    g="$((16#${formatted_hex_string:3:2}))"
    b="$((16#${formatted_hex_string:5:2}))"
    formatted_rgb_string=$(format_to_rgb $r $g $b)
    similarity_perc=$(similarity $r $g $b)
    color_representation=$(printf '\e[%s8;2;%s;%s;%sm▆▆▆▆\e[%s0;0;%s;%s;%sm' "3" "$r" "$g" "$b")
    formatted_strings+=("$similarity_perc $color_representation $formatted_hex_string $formatted_rgb_string")
done

# Addressing the file's rgb color codes:
# Only the relevant bits(r,g and b values) are extracted from full rgb codes into the 'rgb_vals' list.
counter=0
rgb_vals=()
for rgb_related_snippet in "${rgb_strings[@]}"; do
    ((counter++))
    if [ "$rgb_related_snippet" != ")" ] && [ "$counter" -le 3 ]; then
        rgb_vals+=("$rgb_related_snippet")
        if [ "$counter" = 3 ]; then
            formatted_hex_string=#
            for i in {0..2}; do
                hex_substring=$(printf "%x\n" "${rgb_vals[$i]}")
                hex_substring=$(echo "$hex_substring" | tr '[:lower:]' '[:upper:]')
                if [ ${#hex_substring} = 1 ]; then
                    hex_substring=0$hex_substring
                fi
                formatted_hex_string=$formatted_hex_string$hex_substring
            done
            formatted_rgb_string=$(format_to_rgb "${rgb_vals[0]}" "${rgb_vals[1]}" "${rgb_vals[2]}")
            similarity_perc=$( similarity "${rgb_vals[0]}" "${rgb_vals[1]}" "${rgb_vals[2]}" )
            color_representation=$(printf '\e[%s8;2;%s;%s;%sm▆▆▆▆\e[%s0;0;%s;%s;%sm' "3" "${rgb_vals[0]}" "${rgb_vals[1]}" "${rgb_vals[2]}")
            formatted_strings+=("$similarity_perc $color_representation $formatted_hex_string $formatted_rgb_string")
        fi
    elif [ "$rgb_related_snippet" = ")" ]; then
        counter=0
        rgb_vals=()
    fi
done

# '-n' and '-r' for a numeric reversed assortment
printf "%s\n" "${formatted_strings[@]}" | sort | uniq | sort -n -r
