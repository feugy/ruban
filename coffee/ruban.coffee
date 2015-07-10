localStorageKey = '__change'

class Ruban
  constructor: (@options = {}) ->
    @initOptions()
    @$sections = $('section').wrapAll('<div class="ruban"></div>')
    @$ruban    = $('.ruban')

    @toc()
    @current(@$sections.first())
    @pagination()
    @highlight()
    @resize()
    @bind()
    @$ruban.css('transition-property', 'transform')
    @$ruban.css('-webkit-transition-property', '-webkit-transform')
    setTimeout(=>
      @checkHash()
    , 250)

    window.addEventListener('storage', @applyChange, false)

  initOptions: () ->
    @options.ratio              ?= 4/3
    @options.minPadding         ?= '0.4em'
    @options.transitionDuration ?= '1s'
    @options.pagination         ?= false
    @options.title              ?= null
    @options.stripHtmlInToc     ?= false
    @options.bindClicks         ?= false
    @options.bindMouseWheel     ?= false
    @options.fontRatio          ?= 0.4

  bind: ->
    @bindKeys()
    @bindGestures()
    @bindClicks() if @options.bindClicks
    @bindMouseWheel() if @options.bindMouseWheel

    @bindResize()
    @bindHashChange()

  bindKeys: ->
    key('right, down, space, return, j, l, pagedown', @next)
    key('left, up, backspace, k, h, pageup', @prev)
    key('home', @first)
    key('last', @last)
    key('c', @toggleDetails)
    key('p', @togglePresenterMode)

  bindGestures: ->
    Hammer(document, {
      drag_block_vertical:   true,
      drag_block_horizontal: true
    }).on('swipeleft swipeup', @next)
      .on('swiperight swipedown', @prev)

  bindClicks: ->
    @$ruban.contextmenu(-> false)
    @$ruban.mousedown((e) =>
      switch e.which
        when 1 then @next()
        when 3 then @prev()
    )

  bindMouseWheel: ->
    @$ruban.on('wheel', (e) =>
      if e.originalEvent.deltaY > 0
        @next()
      else if e.originalEvent.deltaY < 0
        @prev()
    )

  bindResize: ->
    $(window).resize(=>
      @resize()
      @go(@$current, force: true)
    )

  bindHashChange: ->
    $(window).on('hashchange', @checkHash)

  resize: =>
    parent = @$slides or $(window)
    [outerWidth, outerHeight] = [parent.width(), parent.height()]
    if outerWidth > @options.ratio * outerHeight
      min = outerHeight
      paddingV = @options.minPadding
      @$ruban.parent().css('font-size', "#{min * @options.fontRatio}%")
      @$sections.css(
        'padding-top':    paddingV,
        'padding-bottom': paddingV
      )
      height = @$current.height()
      width = @options.ratio * height
      paddingH = "#{(outerWidth - width)/2}px"
      @$sections.css(
        'padding-left':  paddingH
        'padding-right': paddingH
      )
    else
      min = outerWidth / @options.ratio
      paddingH = @options.minPadding
      @$ruban.parent().css('font-size', "#{min * @options.fontRatio}%")
      @$sections.css(
        'padding-left':  paddingH,
        'padding-right': paddingH
      )
      width = @$current.width()
      height = width / @options.ratio
      paddingV = "#{(outerHeight - height)/2}px"
      @$sections.css(
        'padding-top':    paddingV,
        'padding-bottom': paddingV
      )

  checkHash: =>
    hash = window.location.hash
    if slide = hash.substr(2)
      @go(slide, immediate: true)

  highlight: ->
    hljs.initHighlightingOnLoad()

  first: =>
    @firstSlide()

  firstSlide: ->
    $first = @$current.prevAll('section:first-child')
    @go($first, direction: 'backward')

  prev: =>
    if @hasSteps()
      @prevStep()
    else
      @prevSlide()

  prevSlide: ->
    $prev = @$current.prev('section')
    @go($prev, direction: 'backward')

  prevStep: ->
    @$steps.eq(@index).removeClass('step').fadeOut()
    $prev = @$steps.eq(--@index)
    unless @index < -1
      if $prev.is(':visible')
        $prev.addClass('step').trigger('step')
      else if @index > -1
        @prevStep()
      @propagateChange('prevStep')
    else
      @prevSlide()

  toggleDetails: =>
    @$current.find('details').toggleClass 'opened'

  last: =>
    @lastSlide()

  lastSlide: ->
    $last = @$current.nextAll('section:last-child')
    @go($last, direction: 'forward')

  next: =>
    if @hasSteps()
      @nextStep()
    else
      @nextSlide()

  nextSlide: ->
    $next = @$current.next('section')
    @go($next, direction: 'forward')

  nextStep: ->
    @$steps.eq(@index).removeClass('step')
    $next = @$steps.eq(++@index)
    if $next.length
      $next.fadeIn().addClass('step').trigger('step')
      rand = Math.random()
      @propagateChange('nextStep')
    else
      @nextSlide()

  checkSteps: ($section, direction) ->
    @$steps = $section.find('.steps').children()
    unless @$steps.length
      @$steps = $section.find('.step')

    if direction is 'backward'
      @index = @$steps.length - 1
    else
      @index = -1
      @$steps.hide()

  hasSteps: ->
    @$steps? and @$steps.length isnt 0

  find: (slide) ->
    if slide instanceof $
      slide
    else
      $section = $("##{slide}")
      if $section.length is 0
        $section = @$sections.eq(parseInt(slide) - 1)
      $section

  go: (slide = 1, options = {}) ->
    $section = @find(slide)

    if $section.length and (options.force or not $section.is(@$current))
      @checkSteps($section, options.direction)
      @navigate($section)
      @translate($section, options.immediate)
      @current($section)
      @pagination()
      @propagateChange('go', window.location.hash.replace(/#\//, ''), options)

  navigate: ($section) ->
    window.location.hash = "/#{$section.attr('id') || $section.index() + 1}"

  translate: ($section, immediate = false) ->
    y = $section.prevAll().map(->
      $(@).outerHeight()
    ).get().reduce((memo, height) ->
      memo + height
    , 0)
    @$ruban.css('transition-duration', if immediate then 0 else @options.transitionDuration)
    @$ruban.css('transform', "translateY(-#{y}px)")

  current: ($section) ->
    @$current.removeClass('active').trigger('inactive') if @$current?
    $section.addClass('active').trigger('active')
    @$current = $section

    if @$comments
      @$comments.empty().append($section.find('details').clone())

  pagination: ->
    @paginationText = []
    @paginationText.push @options.title if @options.title
    if @$slides? or @options.pagination or @options.title
      unless @$pagination
        @$pagination = $('<footer class="pagination"></footer>').appendTo(@$commands or @$ruban.parent())
        @total = @$sections.length
      if @options.pagination
        @paginationText.push("#{@$current.index() + 1}/#{@total}")
      @$pagination.html(@paginationText.join(' - '))

  toc: ->
    $toc = $('.toc').first()
    if $toc.length
      stripHtmlInToc = @options.stripHtmlInToc
      $ul = $('<ul/>')

      $('section:not(.no-toc,.toc) > h1:only-child').each(->
        $section = $(this).parent()

        if stripHtmlInToc
          title = html = $(this).text()
        else
          $h1 = $(this).clone()
                       .find('a')
                         .replaceWith(-> $(this).text())
                         .end()
          title = $h1.text()
          html  = $h1.html()

        $('<li/>').append($('<a/>',
          href:  "#/#{$section.attr('id') || $section.index() + 1}"
          title: title
          html:  html
        )).appendTo($ul);
      )
      $toc.append($ul)

  togglePresenterMode: () =>
    @$pagination?.remove()
    delete @$pagination
    if @$slides?
      # Removes presenter markup, and the clock will automatically stops within 1s
      $('body').removeClass('presenter').append(@$ruban)
      @$commands.remove()
      @$comments.remove()
      @$slides.remove()
      delete @$comments
      delete @$commands
      delete @$slides
    else
      # Add the presenter markup and starts clock
      $('body').addClass('presenter').css('font-size', '')
      @$slides = $('<article>').appendTo('body')
      @$slides.append(@$ruban)
      @$comments = $('<aside>').appendTo('body')
      @$commands = $('<header>').appendTo('body')
      @$commands.append('<div class="time">')
      @current(@$current)
      @updateTime()

    @pagination()
    @resize()
    # trigger event when changing
    $('body').trigger('toggle-presenter', {active: $('body').hasClass('presenter'), current: @$current})

  updateTime: () =>
    now = new Date()
    minutes = now.getMinutes();
    @$commands?.find('.time').html "#{now.getHours()}:#{if minutes < 10 then '0' + minutes else minutes}"
    setTimeout(@updateTime, 1000) if @$slides?

  propagateChange: (operation, args...) =>
    # Avoid looping: if the change comes from us, do not re*trigger it
    return if @_propagating
    # If no arguments were given, store a random number to force change detection in localStorage
    unless args.length
      args = [Math.random()]
    # Store stringified value
    localStorage[localStorageKey] = JSON.stringify({
      op: operation,
      args: args
    })

  applyChange: ({key, newValue}) =>
    # Only our key matter
    return unless key is localStorageKey
    {op, args} = JSON.parse(newValue)
    if op of @
      # Use a propagation flag to avoid processing our own events
      @_propagating = true
      # Invoke method named after key, with relevant arguments as value
      @[op].apply(@, args)
      delete @_propagating

window.Ruban = Ruban
