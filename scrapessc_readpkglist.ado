*! version 0.1.0 07jun2026

program define scrapessc_readpkglist, rclass
    version 14.0
    args fileName
    if `"`fileName'"' == "" {
        di as error "file name required"
        exit 198
    }

    tempname fh
    local pkglist ""
    file open `fh' using `"`fileName'"', read
    file read `fh' line
    while r(eof) == 0 {
        if regexm(`"`line'"', "@net:describe[ ]+([^!]+)!") {
            local pkgname = regexs(1)
            local pkglist `"`pkglist' `pkgname'"'
        }
        else if regexm(`"`line'"', "\{net describe ([^:}]+)") {
            local pkgname = regexs(1)
            local pkglist `"`pkglist' `pkgname'"'
        }
        file read `fh' line
    }
    file close `fh'

    local pkglist : list uniq pkglist
    return local pkglist `"`pkglist'"'
    return scalar n = wordcount(`"`pkglist'"')
end
