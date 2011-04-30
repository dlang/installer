_dmd_command_options="$(dmd --help 2>&1 | sed -n 's/^\s*\(-\+\w*\).*/\1/p' | sed 's/filename\|docdir\|directory\|path\|linkerflag\|objdir//g' | sort -u)"

_dmd()
{
    local cur opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    case "${cur}" in
        -L-*) # match linker options
            COMPREPLY=( $( compgen -W "$( ld --help 2>&1 | \
                sed -ne 's/.*\(--[-A-Za-z0-9]\{1,\}\).*/-L\1/p' | sort -u )" -- "$cur" ) )
            ;;
        -L*) # match linker files
            COMPREPLY=( $(compgen -f -P "-L" -- ${cur#-L}) )
            ;;
        -I*) # match import paths
            COMPREPLY=( $(compgen -d -P "-I" -- ${cur#-I}) )
            ;;
        -*) # match dmd options
            COMPREPLY=( $(compgen -W "${_dmd_command_options}" -- ${cur}) )
            ;;
        @*) # match command file
            COMPREPLY=( $(compgen -f -P "@" -- ${cur#@}) )
            ;;
        *) # match d files
            _filedir '@(d|di|D|DI|ddoc|DDOC)'
            ;;
    esac
    return 0
}

complete -F _dmd dmd

_rdmd()
{
    local cur sofar opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    sofar="${COMP_WORDS[@]:1:COMP_CWORD}"
    opts="$_dmd_command_options $(rdmd --help | sed -n 's/^\s*\(--\(\w\|-\)*\).*/\1/p')"

    for i in $sofar
    do
        if [ -e $i ]
        then
            _filedir
            return 0
        fi
    done

    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    else
        _filedir '@(d|di|D|DI|ddoc|DDOC)'
        return 0
    fi
}

complete  -F _rdmd rdmd
