if exists('g:ctrlp_goimpl_loaded')
    finish
endif
let g:ctrlp_goimpl_loaded = 1

call add(g:ctrlp_ext_vars, {
  \ 'init': 'ctrlp#goimpl#init(s:crbufnr)',
  \ 'accept': 'ctrlp#goimpl#accept',
  \ 'exit': 'ctrlp#goimpl#exit()',
  \ 'lname': 'GoImpl',
  \ 'type': 'line',
  \ 'sort': 0,
  \ })


let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
let s:package = ''
let s:strct = ''
function! ctrlp#goimpl#id(...) abort
  let s:package = a:0 > 0 ? a:1 : ''
  let s:strct = a:0 > 1 ? a:2 : ''
  echomsg s:package
  return s:id
endfunction

let s:items = []

function! ctrlp#goimpl#init(bufnr) abort
  if !exists('s:bufnr') | let s:bufnr = a:bufnr | endif
  call s:get_interface_list()
  return s:items
endfunction

function! ctrlp#goimpl#accept(mode, str) abort
    let l:strct = s:strct
    let l:interface = s:get_package(s:package) . '.' . a:str
    call ctrlp#goimpl#exit()
    call ctrlp#exit()
    call s:goimpl(l:interface, l:strct)
endfunction

function! ctrlp#goimpl#exit() abort
    let s:items = []
    let s:package = ''
endfunction

function! s:get_package(package) abort
  if a:package != ''
    return a:package
  endif

  let l:out = system('go mod edit -json | gojq -r .Module.Path')
  if v:shell_error
    echomsg l:out
    return
  endif
  let l:package = split(l:out, '\n')[0]
  return l:package
endfunction

function! s:get_interface_list(...) abort
    let l:package = s:get_package(s:package)

    if !executable('knife')
      echomsg 'knife is need'
      return
    endif

    let l:interfaces = split(system('knife -f "{{range exported .Types}}{{if interface .}}{{.Name}}{{br}}{{end}}{{end}}" ' . l:package), '\n')
    if len(l:interfaces) == 0
      echomsg printf("Can't find interface in %s", l:package)
      return
    endif

    let s:items = l:interfaces
endfunction

function! s:goimpl(interface, strct)
  if !executable('impl')
      echomsg 'impl is need'
      return
  endif

  noau update
  let l:dir = expand('%:p:h')
  if empty(a:interface)
    return
  endif
  let l:strct = a:strct

  let l:matches = []
  if l:strct == ''
    let l:matches = matchlist(getline('.'), 'type \(\w\+\) struct')
    if len(l:matches) == 0
        let l:strct = split(a:interface, '\.')[-1] . 'Impl'
    else
        let l:strct = l:matches[1]
    endif
  endif

  let l:impl = printf('%s *%s', tolower(l:strct[0]), l:strct)
  let l:cmd = printf('impl -dir %s %s %s', shellescape(l:dir), shellescape(l:impl), a:interface)
  let l:out = system(l:cmd)
  let l:lines = split(l:out, '\n')
  if v:shell_error != 0
    echomsg join(l:lines, "\n")
    return
  endif
  if len(l:matches) == 0
    let l:lines = ['type ' . l:strct . ' struct {', '}', ''] + l:lines
  endif
  call append('$', ['']+l:lines)
endfunction
