
twoDigits = (d) ->
	if (0 <= d && d < 10) then return "0" + d.toString();
	if (-10 < d && d < 0) then return "-0" + (-1*d).toString();
	return d.toString();



Date.prototype.toMysqlFormat = ->
	return this.toMysqlDateFormat() + " " + twoDigits(this.getUTCHours()) + ":" + twoDigits(this.getUTCMinutes()) + ":" + twoDigits(this.getUTCSeconds());

Date.prototype.toMysqlDateFormat = ->
	return this.getUTCFullYear() + "-" + twoDigits(1 + this.getUTCMonth()) + "-" + twoDigits(this.getUTCDate())

Date.prototype.toLocalMysqlFormat = ->
	return this.toLocalMysqlDateFormat() + " " + twoDigits(this.getHours()) + ":" + twoDigits(this.getMinutes()) + ":" + twoDigits(this.getSeconds());

Date.prototype.toLocalMysqlDateFormat = ->
	return this.getFullYear() + "-" + twoDigits(1 + this.getMonth()) + "-" + twoDigits(this.getDate())


define ['xyzp/XObject', 'xyzp/XArray', 'xyzp/XValue', 'xyzp/util'], (XObject, XArray, XValue, util) ->
	window.MutationEvents =
		_pauseCount: 0
		_mutations: []
		isPaused: ->
			@_pauseCount
		pause: ->
			@_pauseCount++

		resume: ->
			if !--@_pauseCount
				for {observable:observable, mutation:mutation}, i in @_mutations
					@currentMutation = @_mutations[i]
					observable._fireMutation mutation
				@_mutations = []

		addMutation: (observable, mutation) ->
			@_mutations.push observable:observable, mutation:mutation

	window.ValueCapture = class ValueCapture
		@_valueCaptures:[]
		@_started: false

		constructor: ->
			@_captures = []
			@_tick = 0

		@start: ->
			capture = new ValueCapture
			@_valueCaptures.push capture
			capture

		stop: ->
			_.pull ValueCapture._valueCaptures, @
			# console.log @, @_captures
			@_captures


		@capture: (valueCont, block=null) ->
			# console.log 'capture'#, new Error().stack.split "\n"
			if @_valueCaptures.length
				capture = @_valueCaptures[@_valueCaptures.length - 1]
				++capture._tick
				if capture.pause
					block?()
				else
					captures = capture._captures
					if !_.contains captures, valueCont
						captures.push valueCont
					capture.pause = true
					ret = block?()
					capture.pause = false
					ret

			else
				block?()


	window.xyz =
		XObject:XObject
		XArray:XArray
		XValue:XValue
		ValueCapture:ValueCapture
		MutationEvents:MutationEvents
		util:util
		class: (klass, params...) ->
			for param in params
				if param == 'list'
					klass::__list = true

			klass.observableProxy = (member) ->
				util.observableProxy @, member

			klass.arrayProxy = (member) ->
				util.arrayProxy @, member

			klass.mixin = (obj) ->
				_.extend @::, obj
