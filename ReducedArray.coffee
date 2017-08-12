define ['xyzp/XObject', 'xyzp/XValue', 'xyzp/ObservePool', 'xyzp/util'], (XObject, XValue, ObservePool, util) ->
	class ReducedArray extends XObject
		constructor: (@source, funcs...) ->
			super
			if funcs.length == 1
				@_initFunc = (value) -> value
				@_reduceFunc = funcs[0]
			else
				[@_initFunc, @_reduceFunc] = funcs

			@_value = @addObject new XValue
			@observePool = @addObject new ObservePool
			@update()
			@observeObject @source, '_doUpdate'
			@_value.on 'observeRetain', => @retain()
			@_value.on 'observeRelease', => @release()

		_doUpdate: ->
			if !@_willUpdate
				@_willUpdate = true
				setTimeout (=>
					@update()
					@_willUpdate = false
				), 0

		update: (mutation) ->
			@observePool.allStopObserving()

			if @source.length()
				reducedValue = @_initFunc @source.get(0)

				if @source.length() > 1
					@source.each (el, i) =>
						return if i == 0
						capture = xyz.ValueCapture.start()
						reducedValue = @_reduceFunc reducedValue, el
						captures = capture.stop()
						@observePool.observe observable, (=>@_doUpdate()) for observable in captures
				@_value.set reducedValue
			else
				@_value.set null

		get: -> @_value.get()

		form: -> @


	util.observableProxy ReducedArray, '_value'

	ReducedArray
