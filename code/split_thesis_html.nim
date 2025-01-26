import std / [htmlparser, tables, strutils, strtabs, sugar]
from std / os import createDir, parentDir, `/`, extractFilename

import std / xmltree {.all.}
import std / importutils
privateAccess(XmlNode)

proc findUpTo*(n: XmlNode, tag: string, upToLevel = 1, level = 0, caseInsensitive = false): seq[XmlNode] =
  ## Iterates over all the children of `n` returning those matching `tag`.
  ##
  ## Found nodes satisfying the condition will be appended to the `result`
  ## sequence.
  n.expect xnElement
  for child in n.items():
    if child.k != xnElement:
      continue
    if child.tag == tag or
        (caseInsensitive and cmpIgnoreCase(child.tag, tag) == 0):
      result.add child
    if level < upToLevel: # then recurse
      result.add child.findUpTo(tag, upToLevel, level + 1)

proc findAllOf*(n: XmlNode, tags: seq[string]): seq[XmlNode] =
  ## Iterates over all the children of `n` returning all tags matching any of `tags`
  ##
  ## Found nodes satisfying the condition will be appended to the `result`
  ## sequence.
  n.expect xnElement
  for child in n.items():
    if child.k != xnElement:
      continue
    if child.tag in tags:
      result.add child
    result.add child.findAllOf(tags)

proc getTocNav(f: XmlNode): XmlNode =
  ## The ToC looks something like this:
  ##
  ##   <nav id="table-of-contents" role="doc-toc">
  ##   <h2>Table of Contents</h2>
  ##   <div id="text-table-of-contents" role="doc-toc">
  ##   <ul>
  ##   <li><a href="#orgc7419aa">1. Errata&#xa0;&#xa0;&#xa0;<span class="tag"><span class="extended">extended</span></span></a></li>
  ##   <li><a href="#sec:introduction">2. Introduction&#xa0;&#xa0;&#xa0;<span class="tag"><span class="Intro">Intro</span></span></a></li>
  ##   <li><a href="#sec:about_thesis">3. About this thesis&#xa0;&#xa0;&#xa0;<span class="tag"><span class="Intro">Intro</span></span></a>
  ##
  ## We want the `nav` element (it's only one)
  let nav = f.findAll("nav")
  doAssert nav.len == 1, "Found more than one table of contents!"
  result = nav[0]

proc getToc(nav: XmlNode): XmlNode =
  ## We want the `div` that contains the `<ul>` tags.
  result = nav.child("div")

iterator sections(toc: XmlNode): XmlNode =
  ## Yields all the top level sections of the ToC
  ## ToC contains a single `<ul>` at top level. Just get it and
  ## yield all `<li>` in it.
  for ch in toc.child("ul").findUpTo("li"): # at `level + 1`
    yield ch

#proc getTocSection(toc: XmlNode, sec: string): XmlNode =
#  ## Returns the node corresponding to the given `sec` string (the `href` value)
#  for s in sections(toc):
#
#  raiseAssert "No footnotes found! Are you sure the `upToLevel` is enough?"

proc getLinkTag(x: XmlNode): string =
  ## Returns the link contained in the given `<li>` node.
  doAssert x.tag == "li", "Tag is: " & $x.tag # must be a link
  let a = x.child("a")
  result = a.attrs["href"].dup(removePrefix("#"))

proc getHeadingId(x: XmlNode): string =
  ## Returns the ID of the given heading node (`<h2>`, ...)
  doAssert x.tag[0] == 'h', "Tag is: " & $x.tag # must be a link
  doAssert "id" in x.attrs
  result = x.attrs["id"]

proc findSection(html: XmlNode, section: string): XmlNode =
  ## Returns the outline section diff matching `section`. Given a section like
  ## `#sec:introduction`
  ## returns the div matching:
  ## `<div id="outline-container-sec:introduction" class="outline-2">`
  for s in html.findUpTo("div", upToLevel = 3):
    if "id" notin s.attrs: continue
    let id = s.attrs["id"]
    if id == ("outline-container-" & section):
      result = s

proc getFootnotes(html: XmlNode): XmlNode =
  ## Returns the `footnotes` div in the HTML file:
  ## `<div id="footnotes">`
  for s in html.findUpTo("div", upToLevel = 3):
    if "id" in s.attrs and s.attrs["id"] == "footnotes":
      return s
  raiseAssert "No footnotes found! Are you sure the `upToLevel` is enough?"

type
  #Footnotes =

  OutputFile = object
    path: string ## Path to output HTML file incl filename
    name: string ## Name of the section it came from
    header: string
    toc: string
    body: XmlNode
    bibliography: string
    footnotes: XmlNode

proc initOutputFile(path, name, head: string, body: XmlNode, toc: string, footnotes: XmlNode): OutputFile =
  result = OutputFile(path: path, name: name, header: head, body: body, toc: toc, footnotes: footnotes)

proc writeHint(): string =
  result = """
<div class="hint-message">Click on any heading marked '<span class="extended">extended</span>' to open it</div>
"""

proc writeOutputFile(o: OutputFile) =
  var f = open(o.path, fmWrite)
  f.write("""<!DOCTYPE html>
<html lang="en">
""")

  f.write(o.header & "\n")
  f.write(r"<body>" & "\n")
  f.write("""<div id="content" class="content">""" & "\n")
  f.write(o.toc & "\n")
  f.write($o.body & "\n")
  f.write(o.bibliography & "\n")
  f.write($o.footnotes & "\n")
  f.write(writeHint())
  f.write(r"</div>" & "\n")
  f.write(r"</body>" & "\n")
  f.write(r"</html>" & "\n")
  f.close()

const path = "/home/basti/phd/thesis.html"
const OutDir = currentSourcePath().parentDir.parentDir / "html"

proc toString(x: XmlNode): string =
  ## String converter which makes sure not to break any JS code scripts
  proc impl(x: XmlNode): XmlNode =
    case x.kind
    of xnElement: # check if `script`, if so replace inner text by `xnVerbatimText`
      let tag = x.tag
      let at = x.attrs
      if x.tag == "script" and at.getOrDefault("type") == "text/javascript":
        result = newElement(x.tag)
        result.attrs = x.attrs
        result.add newVerbatimText(x.innerText)
      else:
        result = newElement(x.tag)
        result.attrs = x.attrs
        for ch in x:
          result.add impl(ch)
    else:
      result = x

  result = $impl(x)

proc patchHrefs(x: XmlNode, repl: Table[string, string],
                figTab = initOrderedTable[string, string](),
                footnoteTab = initOrderedTable[string, string]()): XmlNode =
  ## Returns a patched version of `x` which replaced all `repl` keys by their values
  proc impl(x: XmlNode, currentFig: string = ""): XmlNode =
    case x.kind
    of xnElement: # check if `script`, if so replace inner text by `xnVerbatimText`
      let tag = x.tag
      let at = x.attrs
      if tag == "a" and "href" in at: # got a link!
        result = newElement(x.tag)
        result.attrs = at
        if "class" in at and at["class"] == "footref": # footnote reference
          let href = at["href"]
          let nId = footnoteTab[href]
          result.attrs["id"] = "fnr." & nId
          result.attrs["href"] = "#fn." & nId
          result.add newText($nId)
        else:
          let h = at["href"].dup(removePrefix("#"))
          var hnew = repl.getOrDefault(h, h) # reuse existing if not in tab
          if hnew.startsWith("tab") or hnew.startsWith("fig"):
            # patch by adding required prefix `#`
            hnew = "#" & hnew
          elif hnew.startsWith("citeproc"):
            hnew = "./bibliography.html#" & hnew
          result.attrs["href"] = hnew
          # if links to a figure, replace text
          if h in figTab:
            result.add newText(figTab[h])
          else:
            for ch in x:
              result.add impl(ch)
            if result.innerText.len == 0:
              # for reasons I don't understand, if there is nothing contained in
              # the node, the string representation of `<a href...` ends up
              # being a single node, `<a href="..." />`, which breaks the highlighting.
              result.add newText(" ")
      elif tag == "a" and "id" in at: # bibliography at least
        result = newElement(x.tag)
        result.attrs = at
        for ch in x:
          result.add impl(ch)
        if result.innerText.len == 0:
          # for reasons I don't understand, if there is nothing contained in
          # the node, the string representation of `<a href...` ends up
          # being a single node, `<a href="..." />`, which breaks the highlighting.
          result.add newText(" ")
      elif tag == "figcaption":
        result = newElement(x.tag)
        result.attrs = at
        # First child will be `Figure: X`
        doAssert currentFig in figTab, "Figure: " & $currentFig & " does not exist in figure table."
        result.add newText("Figure " & figTab[currentFig] & ": ")
        for ch in x:
          result.add impl(ch)
      else:
        result = newElement(tag)
        result.attrs = at
        let fig = if tag == "figure": at["id"] else: "" # get
        for ch in x:
          result.add impl(ch, fig) # pass down the current figure
    else:
      result = x
  result = impl(x)

proc buildFigTab(x: XmlNode): OrderedTable[string, string] =
  ## Build a table mapping a figure ID to a figure number (possibly with
  ## a ` (a/b/...)` suffix for subfigures.
  var tab = initOrderedTable[string, string]()
  var counter = 0
  var sfCounter = 0
  proc impl(x: XmlNode) =
    case x.kind
    of xnElement:
      let tag = x.tag
      let at = x.attrs
      if tag == "figure":
        doAssert "id" in at
        if "class" notin at or at["class"] == "figure-wrapper":
          sfCounter = 0 # reset subfigure counter
          tab[at["id"]] = (inc counter; $counter)
        else: # is a subfigure
          tab[at["id"]] = $counter & "(" & $char(sfCounter + ord('a')) & ")"
          inc sfCounter
      for ch in x:
        impl(ch)
    else: discard
  impl(x)
  result = tab

proc buildFootnoteTab(x: XmlNode): OrderedTable[string, string] =
  ## Build a table mapping a global footnote ID to a (file)local footnote ID.
  ## Only those footnotes will be printed at the bottom of the file.
  ##
  ## `<a role="doc-backlink" class="footref" id="fnr.82" href="fn.82">82</a>`
  var tab = initOrderedTable[string, string]()
  var counter = 0
  proc impl(x: XmlNode) =
    case x.kind
    of xnElement:
      let tag = x.tag
      let at = x.attrs
      if tag == "a" and "class" in at and at["class"] == "footref":
        doAssert "id" in at
        doAssert "href" in at
        let k = at["href"]
        if k notin tab: # footnotes may be used multiple times
          tab[k] = (inc counter; $counter)
      for ch in x:
        impl(ch)
    else: discard
  impl(x)
  result = tab

proc getName(s: string): string =
  ## Extracts the correct name for the output file from the given `sec:foo:bar`.
  ## If `foo` is `appendix` it means we are looking at an appendix chapter.
  ## We generate the output file name by just replacing any `:` by `_`
  ## If it starts with `sec:` we strip the `sec`
  result = s.replace(":", "_") & ".html"
  if result.startsWith("sec_"):
    result = result.replace("sec_", "")

proc filterFootnotes(x: XmlNode, fTab: OrderedTable[string, string]): XmlNode =
  ## `<a role="doc-backlink" class="footnum" id="fn.89" href="#fnr.89">89</a>`
  doAssert x.tag == "div" and x.attrs.getOrDefault("id") == "footnotes", "Input is not a valid footnote section!"
  let hN = x.child("h2")
  let dF = x[3] # child 0 = text body, child 1 = h2, child 2 = div
  doAssert dF.attrs.getOrDefault("id") == "text-footnotes", "Did not find actual div for footnotes: " & $dF
  let divs = dF.findUpTo("div", 0) # only first level!

  proc linkInTab(n: XmlNode, fTab: OrderedTable[string, string]): bool =
    let at = n.attrs
    doAssert "id" in at
    let id = at["id"]
    result = ("#" & id) in fTab # keep this!

  proc keepElement(n: XmlNode): bool =
    if n.tag == "div" and n.attrs.getOrDefault("class", "") == "footdef":
      # check if has `sup` `a` children
      result = n.child("sup") != nil and n.child("sup").child("a") != nil
    else:
      result = true

  proc filter(x: XmlNode): XmlNode =
    case x.kind
    of xnElement:
      let tag = x.tag
      let at = x.attrs
      if tag == "a" and "class" in at and at["class"] == "footnum":
        # Extract the actual footnote link
        if x.linkInTab(fTab):
          result = newElement(tag)
          result.attrs = at
          let id = at["id"]
          let nId = fTab["#" & id]
          result.attrs["href"] = "#fnr." & nId
          result.attrs["id"] = "fn." & nId
          result.add newText($nId)
      else:
        result = newElement(tag)
        result.attrs = x.attrs
        for ch in x:
          let n = filter(ch)
          if n != nil:
            result.add n
        if result.len == 0 or not result.keepElement(): return nil # return nil, filtered out!
    else: result = x


  var fns = newSeqOfCap[XmlNode](divs.len)
  for ch in divs:
    let n = filter(ch)
    if n != nil: fns.add n
  if fns.len > 0: # only create a non nil output if any footnotes left!
    result = newElement(x.tag)
    result.attrs = x.attrs
    result.add hN # add the section title
    for ch in fns:
      result.add ch
      result.add newText("\n\n")
  else: discard

proc main(fname: string = path, outdir = OutDir) =
  ## The below was the initial idea of the script. It has changed a little bit,
  ## but roughly it's still what we do.
  ##
  ## We will use the existing table of contents to first
  ## build the target file names. Given a link target of:
  ## `<a href="#sec:introduction">`
  ## we will build a file `introduction.html`.
  ## If we encounter a `#org<7 hex>` like link, we throw an error
  ## asking the user (me lol) to fix the link in the original Org file
  #
  ## We then create a table of the `#sec:introduction` links mapping them to
  ## the correct file names.
  #
  ## Later we can then use that table to fix up the internal document links to
  ## external. They will then become, e.g.
  ## `<a href="./introduction.html#sec:introduction">`
  #
  ## We walk over all `<li>` tags in the ToC that are at the level that we want
  ## to split at (default 1). For each element, we walk over the HTML file and
  ## find the correct section in the document. What we actually look for is an
  ## outline counter as follows:
  ## `<div id="outline-container-sec:introduction" class="outline-2">`
  ## produced by Org mode. This container then with certainty contains the entire
  ## new body of the new HTML file.
  #
  ## ???
  #
  ## Then we need to fix up the footnotes. They are global for the entire thesis,
  ## so we will renumber them and make them local to each file. That means adding
  ## a footnote section at the end of the HTML
  #
  ## Finally, we need to preface each new HTML file with the header of the combined
  ## HTML file for the styling and JS.
  let html = loadHtml(fname).child("html") # get the main `html` tag
  let head = html.child("head")
  let body = html.child("body")

  let tocNav = getTocNav(html)
  let toc = getToc(tocNav)

  let fn = html.getFootnotes()
  # given the sections and output files, we can now patch all occurences of links
  var repl = initTable[string, string]()
  var files = newSeq[OutputFile]()
  for s in sections(toc):
    # get the child link
    let name = s.getLinkTag
    let sec = findSection(html, name)
    let path = outdir / getName(name)
    let o = initOutputFile(path, name, toString(head), sec, $tocNav, footnotes = fn)
    files.add o

    let new = "./" & o.path.extractFilename & "#" & o.name
    repl[o.name] = new

    # now walk the body of this section for other headings
    for ch in sec.findAllOf(@["h2", "h3", "h4", "h5", "h6"]):
      let chName = ch.getHeadingId()
      let chNew = "./" & o.path.extractFilename & "#" & chName
      repl[chName] = chNew

  # Patch the links in the table of content
  let newToc = tocNav.patchHrefs(repl)
  ## XXX: Cross file plot links are still (partially?) broken!
  ## -> I think it's fixed?
  for f in mitems(files):
    f.toc = $newToc
    let tab = buildFigTab(f.body) # build table of all figures in section
    let fTab = buildFootnoteTab(f.body) # build table of all footnotes in section
    f.body = f.body.patchHrefs(repl, tab, fTab) # patch the body (replacing figures, footnotes, links)
    f.footnotes = f.footnotes.filterFootnotes(fTab) # filter footnotes to those actually present

    writeOutputFile(f)


when isMainModule:
  import cligen
  dispatch main
