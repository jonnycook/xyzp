define ['xyzp/XObject', 'xyzp/Observable', 'xyzp/util', 'xyzp/XArray'], (XObject, Observable, util, XArray) ->
	class ComputedList extends XObject
		__list:true
		constructor: (@_get, @_name) ->
			super
			@update()

		update: ->
			xyz.ValueCapture.capture @, =>
				capture = xyz.ValueCapture.start()
				list = @_get()
				@conts = capture.stop()
				@allStopObserving()
				@observeObject cont, '_changed' for cont in @conts

				if !list
					list = new XArray
				else if _.isArray list
					list = new XArray list

				@observeObject list, (mutation) =>
					@_fireMutation mutation

				@_list = list

				if @_list != @_prevList
					@_prevList = @_list
					@_fireMutation type:'reset'



		_changed: (mutation) ->
			doChanged = =>
				@update()

			if !@_willUpdate
				@_willUpdate = true
				setTimeout (=>doChanged(); @_willUpdate = false), 0


		hasMethod: (method) ->
			_.isFunction @_list?[method]
			
		call: (method, params...) ->
			if _.isFunction @_list?[method]
				@_list[method] params...

	_.extend ComputedList::, Observable::

	util.arrayProxy ComputedList, '_list'

	ComputedList

