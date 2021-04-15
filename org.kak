provide-module orgmode %&
    # Define our highlighters in the shared namespace,
    # so we can link them later.
    add-highlighter shared/orgmode regions

	# Headers
    add-highlighter shared/orgmode/headers region '^\*' '\n' group
    add-highlighter shared/orgmode/headers/ regex '.+ARCHIVED.+' 0:header+d
    add-highlighter shared/orgmode/headers/ fill 'header'
    add-highlighter shared/orgmode/headers/ regex 'TODO' 0:red
    add-highlighter shared/orgmode/headers/ regex 'DONE' 0:green
	add-highlighter shared/orgmode/headers/priority regions
	add-highlighter shared/orgmode/headers/priority/ region '\[' '\]' fill +i
	add-highlighter shared/orgmode/headers/tags regions
	add-highlighter shared/orgmode/headers/tags/ region ':(?=[\S])' '(?<=[\S]):' fill meta

	# Keywords
    add-highlighter shared/orgmode/keywords region '#\+' '\n' fill "meta"

    add-highlighter shared/orgmode/other default-region group

	# Bullets
	add-highlighter shared/orgmode/other/ regex "^[\s]*[-\+]" 0:bullet

	# Formatting
	add-highlighter shared/orgmode/other/ regex "(?<=[\s])\*[\S][^$\*]*[\S]\*(?=[\s])" "0:+b"
	add-highlighter shared/orgmode/other/ regex "(?<=[\s])/[\S][^$/]*[\S]/(?=[\s])" "0:+i"
	add-highlighter shared/orgmode/other/ regex "(?<=[\s])_[\S][^$_]*[\S]_(?=[\s])" "0:+u"
	add-highlighter shared/orgmode/other/ regex "(?<=[\s])\+[\S][^$\+]*[\S]\+(?=[\s])" "0:+d"
	add-highlighter shared/orgmode/other/ regex "(?<=[\s])~[\S][^$~]*[\S]~(?=[\s])" "0:variable"

	# Checkboxes
	add-highlighter shared/orgmode/other/ regex "(?<=[-\+][\s])\[ \]" "0:red"
	add-highlighter shared/orgmode/other/ regex "(?<=[-\+][\s])\[-\]" "0:yellow"
	add-highlighter shared/orgmode/other/ regex "(?<=[-\+][\s])\[X\]" "0:green"
	add-highlighter shared/orgmode/other/ regex "\[[\d][%%/][\d]\]" "0:+di"

	# Source code
	evaluate-commands %sh{
	  languages="
	    awk c cabal clojure coffee cpp css cucumber d diff dockerfile fish
	    gas go haml haskell html ini java javascript json julia kak kickstart
	    latex lisp lua makefile markdown moon objc perl pug python ragel
	    ruby rust sass scala scss sh swift toml tupfile typescript yaml sql
	  "
	  for lang in ${languages}; do
        printf "try 'require-module ${lang}'\n"
        printf "add-highlighter shared/orgmode/${lang} region \"(?<=#\+BEGIN_SRC ${lang}\\n)\" \"(?=#\+END_SRC)\" group\n"
        printf "add-highlighter shared/orgmode/${lang}/ ref ${lang}\n"
	  done
	}

&

# When a window's `filetype` option is set to this filetype...
hook global WinSetOption filetype=org %{
    # Ensure our module is loaded, so our highlighters are available
    require-module orgmode
    hook window InsertChar \n -group org-indent org-indent-on-new-line

    # Link our higlighters from the shared namespace
    # into the window scope.
    add-highlighter window/orgmode ref orgmode
	map window normal <ret> ':org-toggle-check<ret>' -docstring 'Toggle Check'

    # Add a hook that will unlink our highlighters
    # if the `filetype` option changes again.
    hook -once -always window WinSetOption filetype=.* %{
        remove-highlighter window/orgmode
    }
}

# Lastly, when a buffer is created for a new or existing file,
# and the filename ends with `.org`...
hook global BufCreate .+\.org %{
    # ...we recognise that as our filetype,
    # so set the `filetype` option!
    set-option buffer filetype org
}

define-command -hidden org-indent-on-new-line %{
    evaluate-commands -draft -itersel %{
        # preserve previous line indent
        try %{ execute-keys -draft <semicolon>K<a-&> }
	    # Indent after bullets
		try %{execute-keys -draft "kxs^[\s]*-<ret>ji -<esc>"}
		try %{execute-keys -draft "kxs^[\s]*\+<ret>ji +<esc>"}
		# Titles
		try %{execute-keys -draft "kxs^[\s]*\*<ret><lt>jK<a-&>j<a-gt>"}
     }
}


define-command org-toggle-check -docstring "Toggles a checkbox" %{
	evaluate-commands -draft %{
		try %{
			try %{
				execute-keys "<a-x>s(?<=[\s]\[)[ -](?=\])"
				execute-keys "<ret>rX"
			} catch %{
				execute-keys "<a-x>s(?<=[\s]\[)[-X](?=\])"
				execute-keys "<ret>r "
			}
			try %{
				org-check-total
			}
		} catch %{
			fail "No valid checkbox"
		}
	}
}

define-command org-check-total %{
	evaluate-commands -draft %{
		execute-keys "<a-a>i<a-;>K"
		evaluate-commands -draft %sh{
			HEAD=$(echo "$kak_selection" | head -n 1)
			MAIN_SEL=$(echo "$kak_selection" | tac | head -n -1 | tac)
			INDENTATION=$(echo "$MAIN_SEL" | head -n 1 | sed "s/-.*//g")
			INDENT_ONLY=$(echo "$MAIN_SEL" | grep "^$INDENTATION-")
			CHECK_TOTAL=$(echo "$INDENT_ONLY" | grep "\\([ ]\\|[X]\\)" | wc -l)
			CHECKED=$(echo "$INDENT_ONLY" | grep "[X]" | wc -l)

			printf "execute-keys ';<a-x>'\n"
			printf "execute-keys 's\[[\d]*(/|%%)[\d]*\]<ret>'\n"
			printf "execute-keys 'd'\n"

			ISSLASH=$(echo "$HEAD" | grep "/")
			ISPERCENT=$(echo "$HEAD" | grep "%")

			if [ ! -z "$ISSLASH" ]
			then
				printf "execute-keys 'i[${CHECKED}/${CHECK_TOTAL}]<esc>'\n"
			elif [ ! -z "$ISPERCENT" ]
			then
				PERCENT=$(expr '(' $CHECKED '*' '100' ')' '/' $CHECK_TOTAL)
				printf "execute-keys 'i[${PERCENT}%%]<esc>'\n"
			fi

			if [ "$CHECKED" = "$CHECK_TOTAL" ]
			then
				echo 'try %{
					execute-keys "<a-x>s(?<=[\s]\[)[ -](?=\])"
					execute-keys "<ret>rX"
					org-check-total
				}'
			elif [ "$CHECKED" = 0 ]
			then
				echo 'try %{
					execute-keys "<a-x>s(?<=[\s]\[)[X-](?=\])"
					execute-keys "<ret>r "
					org-check-total
				}'
			else
				echo 'try %{
					execute-keys "<a-x>s(?<=[\s]\[)[X\s](?=\])"
					execute-keys "<ret>r-"
					org-check-total
				}'
			fi
		}
	}
}

