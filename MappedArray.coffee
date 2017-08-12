define ['xyzp/ObservePool'], (ObservePool) ->
	class MappedArray extends xyz.XObject
		xyz.class @
		@observableProxy 'array'
		@arrayProxy 'array'

		constructor: (@source, @mapping) ->
			super
			@array = @addObject new xyz.XArray
			@observePool = @addObject new ObservePool
			@update()
			@observeObject @source, '_doUpdate'
			@array.on 'observeRetain', => @retain()
			@array.on 'observeRelease', => @release()

		_doUpdate: ->
			if !@_willUpdate
				@_willUpdate = true
				setTimeout (=>@update(); @_willUpdate = false), 0


		update: ->
			# console.log 'update',@
			@array.clear()
			@observePool.allStopObserving()
			@source.each (el) =>
				capture = xyz.ValueCapture.start()
				mappedValue = @mapping el
				captures = capture.stop()
				@observePool.observe observable, (=>@_doUpdate()) for observable in captures
				@array.push mappedValue
