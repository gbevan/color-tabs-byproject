ColorTabs = null
logger = null
log = null
reloader = null

pkgName = "color-tabs-byproject"

module.exports = new class Main
  colorTabs: null
  colorChangeCb: []
  config:
    backgroundStyle:
      title: "Background style"
      type: "string"
      default: "gradient"
      enum: ["gradient","solid","none"]
    borderStyle:
      title: "Border style"
      type: "string"
      default: "none"
      enum: ["top","bottom","left","right","none"]
    borderSize:
      title: "Border thickness"
      type: "integer"
      default: "6"
    markerStyle:
      title: "Marker style"
      type: "string"
      default: "none"
      enum: ["corner","round","square","none"]
    colorSelection:
      title: "Colors"
      description: "Deterministic, the color is based on the path of the file, so each file has a specific and predictable color."
      type: "string"
      default: "deterministic"
      enum: ["deterministic"]
    referTo:
      title: "Custom rules based on"
      description: "Set rules based on project name, or project full path"
      type: "string"
      default: "project path"
      enum: ["project name", "project path"]
    folderDepth:
      title: "Folder Depth"
      description: "Folder Depth to have own color in project (see Edit Rules for per-project rules)"
      type: "integer"
      default: "0"
    autoColor:
      title: "Color new tabs automatically"
      description: "If enabled, every new tab you open will automatically be colored."
      type: 'boolean'
      default: true
    debug:
      type: "integer"
      default: 0
      minimum: 0

  activate: ->
    if atom.inDevMode()
      setTimeout (->
        reloaderSettings = pkg:pkgName,folders:["lib","styles"]
        try
          reloader ?= require("atom-package-reloader")(reloaderSettings)
        ),500
    unless log?
      logger = require("atom-simple-logger")(pkg:pkgName)
      log = logger("main")
      log "activating"
    unless @colorTabs?
      log "loading core"
      load = =>
        try
          ColorTabs ?= require "./color-tabs-byproject"
          @colorTabs = new ColorTabs(logger)
        catch
          log "loading core failed"
        if @colorTabs?
          @colorTabs.setColorChangeCb @colorChangeCb
          @color = @colorTabs.color
      # make sure it activates only after the tabs package
      if atom.packages.isPackageActive("tabs")
        load()
      else
        @onceActivated = atom.packages.onDidActivatePackage (p) =>
          if p.name == "tabs"
            load()
            @onceActivated.dispose()

  provideChangeColor: ->
    return (path,color, save=true, warn=false) =>
      @color? path, color, save, warn

  provideColorChangeCb: ->
    return (cb, add=true) =>
      @colorChangeCb.push cb
      for path, color of @colorTabs.getColors()
        cb path, color
      return dispose: =>
        if @colorChangeCb?
          index = @colorChangeCb.indexOf cb
          if index > -1
            @colorChangeCb.splice index,1

  deactivate: ->
    log "deactivating"
    @onceActivated?.dispose?()
    @colorTabs?.destroy?()
    @colorTabs = null
    if atom.inDevMode()
      log = null
      ColorTabs = null
      colorChangeCb = null
      reloader?.dispose()
      reloader = null
