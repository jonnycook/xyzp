define ['xyzp/XObject', 'xyzp/XArray', 'xyzp/ObservePool', 'xyzp/util'], (XObject, XArray, ObservePool, util) ->
	class FilteredArray extends XObject
		constructor: (@source, @test) ->
			super
			if _.isPlainObject @test
				throw new Error()
			@array = @addObject new XArray
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
			@array.clear()
			@observePool.allStopObserving()
			@source.each (el) =>
				capture = xyz.ValueCapture.start()
				test = @test el
				captures = capture.stop()
				@observePool.observe observable, (=>@_doUpdate()) for observable in captures

				if test
					@array.push el

	util.observableProxy FilteredArray, 'array'
	util.arrayProxy FilteredArray, 'array'

	FilteredArray
