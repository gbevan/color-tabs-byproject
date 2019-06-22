sep = require("path").sep
dirname = require("path").dirname
basename = require("path").basename
debug = require('debug')('color-tabs-byproject')
CSON = require 'season'
rulesFile = atom.getConfigDirPath()+"#{sep}color-tabs-byproject-rules.cson"
rules = {}
colorChangeCb = null
cssElements = {}
hashbow = require("hashbow")

getCssElement = (path, color) ->
  cssElement = cssElements[path]
  unless cssElement?
    cssElement = document.createElement 'style'
    cssElement.setAttribute 'type', 'text/css'
    cssElements[path] = cssElement
  while cssElement.firstChild?
    cssElement.removeChild cssElement.firstChild
  return cssElement unless color
  path = path.replace(/\\/g,"\\\\")
  cssBuilder = (oldcss="",{css, theme, active, marker, before, after}) ->
    selector = "ul.tab-bar>li.tab[data-path='#{path}'][is='tabs-tab']"
    if theme?
      selector = "atom-workspace.theme-#{theme} " + selector
    if marker
      selector = selector + " .marker"
    if active
      selector = selector + ".active"
    pureSelector = selector
    if before
      selector = selector + "," + pureSelector + ":before"
    if after
      selector = selector + "," + pureSelector + ":after"
    return "#{oldcss}#{selector}{#{css}}"
  css = ""

  switch atom.config.get("color-tabs-byproject.backgroundStyle")
    when "gradient"
      css  = cssBuilder css,
        css: "background-image:
        -webkit-linear-gradient(top, #{color} 0%, rgba(0,0,0,0) 60%);"
        before: true
        after: true
      css = cssBuilder css,
        css: "background-image:
        -webkit-linear-gradient(top, #{color} 0%, rgba(0,0,0,0) 60%);"
        theme: "isotope-ui"
        before: true
        after: true
      css = cssBuilder css,
        css: "background-image:
        -webkit-linear-gradient(top, #{color} 0%, rgba(0,0,0,0) 60%);"
        theme: "atom-light-ui"
        before: true
        after: true
        active: true
      css = cssBuilder css,
        css: "background-image:
        -webkit-linear-gradient(top, #{color} 0%, #d9d9d9 60%);"
        theme: "atom-light-ui"
        before: true
        after: true
      css = cssBuilder css,
        css: "background-image:
        -webkit-linear-gradient(top, #{color} 0%, #222222 60%);"
        theme: "atom-dark-ui"
        before: true
        after: true
        active: true
      css = cssBuilder css,
        css: "background-image:
        -webkit-linear-gradient(top, #{color} 0%, #333333 60%);"
        theme: "atom-dark-ui"
        before: true
        after: true
    when "solid"
      if parseInt(color.replace('#', ''), 16) > 0xffffff/2
        text_color = "black"
      else
        text_color = "white"
      css = cssBuilder css,
        css: "background-color: #{color}; color: #{text_color};
        background-image: none;"
        before: true
        after: true
      css = cssBuilder css,
        css: "background-color: #{color};"
        theme: "isotope-ui"
        before: true
        after: true

  border = atom.config.get("color-tabs-byproject.borderStyle")
  borderSize = atom.config.get("color-tabs-byproject.borderSize")
  unless border == "none"
    css = cssBuilder css,
      css: "box-sizing: border-box;
        border-#{border}: solid #{borderSize}px #{color};
        border-image: none;
      "
      before: border == "top" or border == "bottom"
      after: border == "top" or border == "bottom"

  marker = atom.config.get "color-tabs-byproject.markerStyle"
  unless marker == "none"
    css = cssBuilder css,
      css: "display: inline-block;
        width: 0;
        height: 0;
        right: 0;
        top: 0;
        border-style: solid;
        position: absolute;"
      marker: true

    switch marker
      when "corner"
        css = cssBuilder css,
          css: "border-color: transparent #{color} transparent transparent;
            border-width: 0 20px 20px 0;"
          marker: true
      when "round"
        css = cssBuilder css,
          css: "border-color: #{color};
            border-width: 6px;
            border-radius: 10px;"
          marker: true
      when "square"
        css = cssBuilder css,
          css: "border-color: #{color};
            border-width: 6px;
            border-radius: 3px;"
          marker: true
  cssElement.appendChild document.createTextNode css
  return cssElement

getDeterministicColor= (path) ->
  projPath = path

  folderDepth = atom.config.get "color-tabs-byproject.folderDepth"
  if rules && rules.projects && rules.projects[projPath]
    if rules.projects[projPath].folderDepth
      folderDepth = rules.projects[projPath].folderDepth

  if folderDepth > 0
    relPath = atom.project.relativizePath(projPath)[1]
    subPath = dirname(relPath).split(sep, folderDepth)
    projPath += subPath
  return hashbow(projPath)

getColorForPath = (path) ->
  switch atom.config.get "color-tabs-byproject.colorSelection"
    when 'deterministic'
      projPath = resolveProjPath path
      projName = basename projPath
      switch atom.config.get "color-tabs-byproject.referTo"
        when 'project name'
          if rules && rules.projects && rules.projects[projName] && rules.projects[projName].color
            return rules.projects[projName].color
          else
            return getDeterministicColor(projName)
        when 'project path'
          if rules && rules.projects && rules.projects[projPath] && rules.projects[projPath].color
           return rules.projects[projPath].color
          else
            return getDeterministicColor(projPath)

resolveProjPath = (path) ->
  if !path
    return ''
  relPath = atom.project.relativizePath(path)[1]
  debug 'relPath:', relPath

  regPath = relPath.replace(/\\/g, '\\\\')
  debug 'regPath:', regPath
  
  projPath = path.replace(new RegExp("#{regPath}$"), "")
  return projPath

processPath= (path,color,revert=false,save=false,warn=false) ->
  unless path?
    if warn
      atom.notifications.addWarning "coloring a unsaved tab is not supported"
    return
  cssElement = getCssElement path, color
  unless revert
    if save
      projPath = resolveProjPath path
      if projPath != ""
        if !rules.projects[projPath]
          rules.projects[projPath] = {}
        rules.projects[projPath].color = color
        CSON.writeFile rulesFile, rules, (err) ->
          if err
            console.error 'ERROR: writing rules file:', err
          else
            debug 'Wrote rules file'

    # NOTE: Markdown previewer tabs cannot be colored this way.
    tabDivs = atom.views.getView(atom.workspace)
      .querySelectorAll "ul.tab-bar>
        li.tab[data-type='TextEditor']>
        div.title[data-path='#{path.replace(/\\/g,"\\\\")}']"

    for tabDiv in tabDivs
      tabDiv.parentElement.setAttribute "data-path", path
      marker = tabDiv.querySelector ".marker"
      unless marker?
        marker = document.createElement 'div'
        marker.className = 'marker'
        tabDiv.appendChild marker
    unless cssElement.parentElement?
      head = document.getElementsByTagName('head')[0]
      head.appendChild cssElement
  else
    if save
      projPath = resolveProjPath path
      if projPath != ""
        if rules.projects[projPath] && rules.projects[projPath].color
          delete rules.projects[projPath].color
        CSON.writeFile rulesFile, rules, (err) ->
          if err
            console.error 'ERROR: writing rules file:', err
          else
            debug 'Wrote rules file'

    if cssElement.parentElement?
      cssElement.parentElement.removeChild(cssElement)
  if colorChangeCb?
    for cb in colorChangeCb
      unless revert
        cb path, color
      else
        cb path, false

loadRules = (next) ->
  debug 'in loadRules'
  CSON.readFile rulesFile, (err, content) =>
    unless err
      rules = content
    if !rules
      rules = {}
    if !rules.projects
      rules.projects = {}
    debug 'rules loaded:', rules
    next(err)

processAllTabs = (revert=false)->
  debug "processAllTabs, reverting:#{revert}"
  paths = []
  paneItems = atom.workspace.getPaneItems()
  for paneItem in paneItems
    debug 'processAllTabs class:', paneItem.constructor.name, 'paneItem:', paneItem
    if paneItem.getPath?
      path = paneItem.getPath()
      debug 'processAllTabs panel path:', path
      if paths? and paths.indexOf(path) == -1
        paths.push path
    else
      debug 'WARNING path not resolved for paneItem:', paneItem
  debug "found #{paths.length} different paths with color of
    total #{paneItems.length} paneItems"
  for path in paths
    debug 'calling processPath:', path
    processPath path, getColorForPath(path), revert
  return !revert

{CompositeDisposable} = require 'atom'
paths = {}

module.exports =
class ColorTabsByProject
  disposables: null

  constructor: (logger) ->
    debug 'in constructor'
    loadRules =>
      @processed = processAllTabs()
      debug 'after processAllTabs called, processed:', @processed

      unless @disposables?
        @disposables = new CompositeDisposable
        cb = processAllTabs.bind(this)

        # Look for current Panes to add listeners
        panes = atom.workspace.getPanes()
        debug 'panes:', panes
        for pane in panes
          # process editor panes in center window
          debug 'pane parent:', pane.parent
          if pane.parent.location == 'center' || (pane.parent.parent && pane.parent.parent.location == 'center')
            debug 'Adding onDidAddPane handler on initial (center) pane:', pane
            @disposables.add pane.onDidAddItem (event) ->
              debug 'initial pane onDidAddItem event:', event
              setTimeout processAllTabs, 10

        debug 'Adding onDidAddPane handler'
        @disposables.add atom.workspace.onDidAddPane (event) =>
          debug 'in onDidAddPane event:', event
          setTimeout processAllTabs, 10

          if event.pane
            debug 'Adding onDidAddPane handler on new pane:', event.pane
            @disposables.add event.pane.onDidAddItem (event) ->
              debug 'pane onDidAddItem event:', event
              setTimeout processAllTabs, 10

        debug 'Adding onDidDestroyPane handler'
        @disposables.add atom.workspace.onDidDestroyPane (event) ->
          debug 'in onDidDestroyPane event:', event
          setTimeout processAllTabs, 10

        @disposables.add atom.workspace.observePaneItems (item) ->
          debug 'in observePaneItems item:', item
          setTimeout processAllTabs, 10

        debug 'Adding onDidAddTextEditor handler'
        @disposables.add atom.workspace.onDidAddTextEditor (event) ->
          debug 'in onDidAddTextEditor:', event
          debug 'onDidAddTextEditor event:', event
          if atom.config.get("color-tabs-byproject.autoColor")
            te = event.textEditor
            if te?.getPath?
              processPath te.getPath(), getColorForPath(te.getPath()), false, true
          setTimeout processAllTabs, 10

        @disposables.add atom.workspace.onDidAddPaneItem (event) ->
          debug 'in onDidAddPaneItem event:', event
          setTimeout processAllTabs, 10

        @disposables.add atom.workspace.onDidDestroyPaneItem (event)->
          debug 'in onDidDestroyPaneItem event:', event
          setTimeout processAllTabs, 10

        @disposables.add atom.commands.add 'atom-workspace',
          'color-tabs-byproject:toggle': @toggle
          'color-tabs-byproject:color-current-tab': =>
            te = atom.workspace.getActiveTextEditor()
            if te?.getPath?
              @color te.getPath(), getColorForPath(te.getPath()), true, true
            else
              atom.notifications.addWarning "coloring is only possible for file tabs"
          'color-tabs-byproject:uncolor-current-tab': =>
            te = atom.workspace.getActiveTextEditor()
            if te?.getPath?
              @color te.getPath(), false

        @disposables.add atom.commands.add 'atom-workspace', 'color-tabs-byproject:edit-rules': => @editRules(cb)

        @disposables.add atom.config.observe("color-tabs-byproject.backgroundStyle",@repaint)
        @disposables.add atom.config.observe("color-tabs-byproject.borderStyle",@repaint)
        @disposables.add atom.config.observe("color-tabs-byproject.borderSize",@repaint)
        @disposables.add atom.config.observe("color-tabs-byproject.markerStyle",@repaint)
        @disposables.add atom.config.observe("color-tabs-byproject.colorSelection",@repaint)

        atom.workspace.observeTextEditors (editor) =>
          debug 'constructor getPath:', editor.getPath(), 'rulesFile:', rulesFile
          if editor.getPath() == rulesFile
            @addSaveCb(editor, cb)
      # setTimeout processAllTabs, 1000
      debug "loaded"

  color: (path, color, save=true, warn=false) ->
    processPath path, color, !color, save, warn

  setColorChangeCb: (instance)->
    colorChangeCb = instance

  repaint: =>
    debug 'in repaint'
    if @processed
      processAllTabs()

  toggle: =>
    debug 'in toggle'
    @processed = processAllTabs(@processed)

  destroy: =>
    debug 'in destroy'
    @processed = processAllTabs(true)
    @disposables?.dispose()
    @disposables = null
    sep = null
    CSON = null

  addSaveCb: (editor, cb) ->
    debug 'in addSaveCb'
    @disposables.add editor.onDidSave =>
      debug('addSaveCb onDidSave called, reloading rules')
      loadRules =>
        setTimeout cb, 10

  editRules: (cb) =>
    debug 'in editRules'
    atom.open pathsToOpen: rulesFile
    atom.workspace.observeTextEditors (editor) =>
      debug 'editRules getPath:', editor.getPath(), 'rulesFile:', rulesFile
      if editor.getPath() == rulesFile
        @addSaveCb(editor, cb)
