[ -n $BASH_VERSION ] || exit

D() {
    [[ $BASH_COMMAND = PS ]] && PROMPT=1
    [[ -n $PROMPT ]] || [[ -n $BUSY ]] && return

    SECONDS=0
    BUSY=1
}
PS() {
    Pr=$?
    [[ $Pr -eq 0 ]] && Pr= || Pr="($Pr) "

    Pt=
    if [[ -n $BUSY ]] && [[ $SECONDS -ge 10 ]]
    then
        Pt='('
        [[ $SECONDS -ge 3600 ]] && Pt+=$(printf %02u: $((SECONDS/3600)))
        Pt+=$(printf %02u:%02u $(((SECONDS%3600)/60)) $((SECONDS%60)))
        Pt+=') '
    fi

    [[ $UID -eq 0 ]] && Pu=31 || Pu=32
}
PE() {
    unset -v PROMPT BUSY
}
trap D DEBUG
PROMPT_COMMAND=(PS "${PROMPT_COMMAND[@]}" PE)
PS1='\[\e[1;${Pu}m\]\u@\h\[\e[0m\] \[\e[1;34m\]\w\[\e[0m\] \[\e[1;33m\]$Pt\[\e[0m\]\[\e[1;31m\]$Pr\[\e[0m\]\$ '

export HISTCONTROL=ignorespace
export EDITOR=nvim

#### aliases ####
alias d="lsblk -do NAME,SIZE,TRAN,MODEL,SERIAL,WWN"
alias i="systemd-inhibit --what=sleep:handle-lid-switch sleep inf"
alias l="ls -lh --color=auto --hyperlink=auto"
alias r="rsync -rltPhv --inplace --copy-devices --mkpath --timeout=30"
alias s="ssh $s"
alias t="s -N -D8080 -L8008:localhost:8008"
alias y="yt-dlp --add-metadata --embed-subs --sub-lang=en,fi,fi-FI --retries=30 --retry-sleep=10"

alias ga="git add"
alias gc="git commit"
alias gd="git diff"
alias gl="git log"
alias gp="git push"
alias gr="git rebase"
alias gs="git status"
alias la="l -a"
alias pm="pulsemixer"
alias ra="r -gop"
alias rc="r --zc=zstd --zl=9"
alias rv="r -I --no-W"
alias yc="y --cookies-from-browser=chromium:~/.var/app/org.chromium.Chromium/config/chromium"

alias mpv="flatpak run io.mpv.Mpv"


#### functions ####
b() { ("$@" &>/dev/null & disown) ;}
o() {
    tmux has-session  -to 2>/dev/null && tmux kill-session -to
    tmux new-session  -so -d -x$(tput cols) -y$(tput lines) ollama serve
    tmux split-window -to -v -l90%
    tmux send-keys    -to ' clear; readarray -t m < <(ollama list | tail -n+2 | cut -d" " -f1); [[ ${#m[@]} -ne 1 ]] && select m in "${m[@]}"; do break; done; exec ollama run $m' Enter
    tmux attach       -to 
}
fav() {
    local input=$1 name=${1##*/} name=${name%.*} output=${2:-$name-fav.mp4} crf=${3:-35} preset=${4:-4}
    ffmpeg -i "$file" -c:v libsvtav1 -preset $preset -crf $crf -svtav1-params tune=0 "$output"
}
fs() {
    local F="$1" N="${1##*/}" VC=${2:-hevc} Q=${3:-30} S="${4/#[1-9]*/-vf scale_cuda=&:-1}" L=4

    [[ -z $S ]] && ((L--))
    shift $(( $# < $L ? $# : $L ))

    ffmpeg -loglevel error -stats -hwaccel cuda -hwaccel_output_format cuda -i "$F" -map 0 \
        -c:v ${VC}_nvenc -cq $Q -preset p7 $S                                              \
        -c:a libopus -b:a 96k -ac 2 -c:s copy -strict unofficial "$@" "${N%.*}-fs.mkv"
}
fps() {
    local I=$(ffprobe -select_streams s:m:language:eng -show_entries stream=index:disposition=forced,hearing_impaired -of json "$1" \
        | jq '.streams | map(select(.disposition.forced == 0)) | min_by([.disposition.hearing_impaired, .index]) | .index')

    if [[ -z $I ]]
    then
        echo "nothing matched"
        return 1
    fi

    ffmpeg -i "$1" -map 0:"$I" -c copy "${1%.mkv}".sup
    pgsrip "${1%.mkv}".sup
    rm     "${1%.mkv}".sup
    mv     "${1%.mkv}"{,.en}.srt
}
m() {
    ip route show default | column -tH4,6,7,8

    echo
    local IFS=$'\n'
    select C in $(nmcli -t -f DEVICE,NAME connection show --active | rg -v "^lo:")
    do
        read -p "metric: " M
        sudo nmcli connection modify "${C#*:}" ipv4.route-metric "$M"
        sudo nmcli connection up     "${C#*:}"
        break
    done
}
n() {
    NNN_RCLONE="rclone mount --vfs-cache-mode=writes --vfs-cache-max-age=20m --vfs-cache-max-size=512M" \
        NNN_PLUG='m:-!|/usr/lib/nnn/plugins/md5sum "$nnn"' nnn -d "$@"

    if [[ -f   ~/.config/nnn/.lastd ]]
    then
        source ~/.config/nnn/.lastd
        rm     ~/.config/nnn/.lastd
    fi
}
se() {
    audit2allow -i $1 -M $1
    sudo semodule -i $1.pp
}


#### completions ####
ca() {
    eval "_comp_cmd_$1() {
        unset -f _comp_cmd_$1
        _comp_load $2

        if [[ $2 = git ]]
        then
            __git_complete $1 git_$3
            __git_wrap_git_$3 \"\$@\"
            return
        fi

        local complete=\$(complete -p $2 | sed 's/ \w*$//')
        local complete_func=\$(rg -oP -- '-F \K[^ ]+' <<< \$complete)

        \$complete $1
        \$complete_func \"\$@\"
    }"
    complete -F _comp_cmd_$1 $1
}
ca r rsync
ca s ssh
ca y yt-dlp

ca ra rsync
ca rv rsync

ca ga git add
ca gc git commit
ca gd git diff
ca gl git log
ca gp git push
ca gr git rebase
ca gs git status
