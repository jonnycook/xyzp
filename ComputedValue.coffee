define ['xyzp/XObject', 'xyzp/Observable'], (XObject, Observable) ->
	class ComputedValue extends XObject
		__valueContainer:true
		constructor: (@_get, @_name) ->
			super
			@update true


		update: (first=false)->
			xyz.ValueCapture.capture @, =>
				capture = xyz.ValueCapture.start()

				value = @_get (c) => @_cont = c
				@conts = conts = capture.stop()
				@allStopObserving()
				for cont in conts
					@observeObject cont, '_changed' 
					cont.marks ?= []
					cont.marks.push @_name

				@_value = value

				if first
					@_prevValue = value

		get: ->
			xyz.ValueCapture.capture @
			@_value

		set: (value) ->
			if @_set
				@_set value
			else if @_cont
				@_cont.set value

		_changed: ->
			if @_debug
				console.log 'asdf'
			doChanged = =>
				@update()
				if @_value != @_prevValue
					@_fireMutation type:'set', value:@_value, prevValue:@_prevValue
					@_prevValue = @_value


			if !@_willUpdate
				@_willUpdate = true
				clearTimeout @_timerId
				@_timerId = setTimeout (=>doChanged(); @_willUpdate = false), 0

		form: (type) ->
			if @_cont
				@_cont.form type
			else
				@


		meta: (query) -> 
			if @_cont
				@_cont.meta query

	_.extend ComputedValue::, Observable::
	ComputedValue
