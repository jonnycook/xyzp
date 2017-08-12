define ['xyzp/Observable', 'xyzp/XObject', 'xyzp/ObservePool', 'xyzp/util'], (Observable, XObject, ObservePool, util) ->
	class PropertyPath extends XObject
		__valueContainer: true
		constructor: (@object, path, @params...) ->
			super
			@parts = path.split '.'
			@prevValue = @get()
			@_update()

		_doUpdate: ->
			if !@_willUpdate
				@_willUpdate = true
				setTimeout (=>@_update(); @_willUpdate = false), 0


		_update: ->
			@allStopObserving()
			obj = @object
			for propName, i in @parts
				if obj
					if util.isList obj
						if i != @parts.length - 1
							# @observeObject prop, '_changed'
						# else
							# @observeObject prop, '_doUpdate'
							obj = obj.get propName
					else
						prop = obj.prop propName, @params...

						if i == @parts.length - 1
							@observeObject prop, '_changed'
						else
							@observeObject prop, '_doUpdate'
							obj = obj.get propName
				else
					break
			@_changed()

		_changed: ->
			value = @get()
			if @prevValue != value
				@prevValue = value
				@_fireMutation type:'set', value:value

		_prop: ->
			obj = @object
			for propName, i in @parts
				if obj
					if i == @parts.length - 1
						return obj.prop propName, @params...
					else
						obj = obj.get propName
				else
					return undefined

		get: ->
			prop = @_prop()
			if prop
				prop.get()
			else
				undefined

		value: (context) ->
			prop = @_prop()
			if prop
				prop.value context
			else
				undefined

		form: (context) ->
			prop = @_prop()
			if prop
				prop.form context
			else
				undefined


		set: (value, context) ->
			prop = @_prop()
			if prop
				prop.set value, context


		meta: (query) ->
			prop = @_prop()
			if prop
				prop.meta query


	_.extend PropertyPath::, Observable::
	PropertyPath
