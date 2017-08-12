define ['xyzp/XObject', 'xyzp/XArray', 'xyzp/ObservePool', 'xyzp/util'], (XObject, XArray, ObservePool, util) ->
	class ArraySlice extends XObject
		constructor: (@source, @begin, @end) ->
			super
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

			for i in [@begin..@end]
				break if i >= @source.length()
				@array.push @source.get(i)

	util.observableProxy ArraySlice, 'array'
	util.arrayProxy ArraySlice, 'array'

	ArraySlice
