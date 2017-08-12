define ['xyzp/XObject', 'xyzp/XArray', 'xyzp/ObservePool', 'xyzp/util'], (XObject, XArray, ObservePool, util) ->
	class SortedArray extends XObject
		constructor: (@source, @compare) ->
			super
			@array = @addObject new XArray
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
			array = []
			@source.each (el) =>
				array.push el
			array.sort @compare
			for el in array
				@array.push el

	util.observableProxy SortedArray, 'array'
	util.arrayProxy SortedArray, 'array'

	SortedArray
