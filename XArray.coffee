define ['xyzp/Observable', 'xyzp/XObject'], (Observable, XObject) ->
	class XArray extends XObject
		__list:true

		@derive: {}
		constructor: (@_array=[]) ->
			# @__defineGetter__ 'length', -> @_array.length
			# @_array = []

		_addProperty: (i) ->
			# if !Object.getOwnPropertyDescriptor @, i
			# 	Object.defineProperty @, i,
			# 		get: -> @get i
			# 		set: (value) => @set i, value

		set: (index, value) ->
			# @_addProperty i for i in [0..index]
			# console.log @_array[index], value
			@_array[index] = value

		setArray: (array) ->
			@clear()
			for el in array
				@push el

		get: (index) ->
			if index == 'length'
				@length()
			else
				@_array[index]

		push: (value) ->
			@_array.push value
			@_addProperty @_array.length - 1
			@_fireMutation type:'insertion', position:@_array.length - 1, value:value

		add: (value) -> @push value

		unshift: (value) ->
			@_array.unshift value
			@_addProperty @_array.length - 1
			@_fireMutation type:'insertion', position:0, value:value
	
		delete: (index) ->
			value = @_array[index]
			@_array.splice index, 1
			@_fireMutation type:'deletion', position:index, value:value


		clear: ->
			while @_array.length
				@delete 0

		contains: (value) ->
			@_array.indexOf(value) != -1


		remove: (value) ->
			index = @_array.indexOf value
			if index != -1
				@delete index

		each: (iter) ->
			xyz.ValueCapture.capture @
			for el, i in @_array
				iter el, i

		forEach: (iter) -> @each iter

		findOne: (predicate) ->
			for el, i in @_array
				if predicate el, i
					return el
			null

		find: (predicate) ->
			results = []
			for el, i in @_array
				if predicate el, i
					results.push el

			results

		length: ->
			xyz.ValueCapture.capture @
			@_array.length

		derive: (type, params...) ->
			if XArray.derive[type]
				XArray.derive[type] @, params...
			else
				@

		value: -> @



	_.extend XArray::, Observable::

	XArray