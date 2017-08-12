define ['xyzp/ModelProperty', 'xyzp/ComputedValue', 'xyzp/Observable'], (ModelProperty, ComputedValue, Observable) ->
	class ModelAttribute extends ModelProperty
		__valueContainer: true

		constructor: ->
			super
			if @_schema.init
				@_schema.init.call @

		init: ->
			if @_schema.type == 'computed'
				if @_schema.get
					@_computedValue = new ComputedValue (=> @_schema.get.apply @_instance, @_params), @_name
				else if @_schema.prop
					@_computedValue = @_schema.prop.apply @_instance, @_params

				@addObject @_computedValue
				@_computedValue.observe (mutation) =>
					@_fireMutation mutation

		destruct: ->
			if @_schema.destruct
				@_schema.destruct()
			super

		_changed: ->
			@_fireMutation type:'set', value:@get()

		_set: (value, from) ->
			switch @_schema.type
				# when 'computed'
				# 	@_schema.set.call @_instance, value
				when 'datetime'
					if _.isString value
						if from == 'applyChanges' && value.match /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/
							arr = value.split(/[- :]/)
							value = new Date Date.UTC(arr[0], arr[1]-1, arr[2], arr[3], arr[4], arr[5])
							if !value.isValid()
								value = null
						else
							if value
								value = Date.create value
							else
								value = null
				when 'date'
					if _.isString value
						if from == 'applyChanges' && value.match /^\d{4}-\d{2}-\d{2}$/
							arr = value.split(/[- :]/)
							value = new Date(arr[0], arr[1]-1, arr[2])
							if !value.isValid()
								value = null
						else
							if value
								value = Date.create value
							else
								value = null

				when 'int'
					value = parseInt value

				when 'bool'
					value = !!value

				when 'float'
					value = parseFloat value

				when 'computed'
					if @_schema.set
						value = @_schema.set.call @_instance, value
					else
						return

				when 'duration'
					if _.isString value
						try
							value = juration.parse value
						catch e
							value = 0

			if @_schema.type == 'object' || @_value != value
				@_value = value
				@_changed()
				true
			else
				false

		get: ->
			xyz.ValueCapture.capture @, =>
				switch @_schema.type
					when 'computed'
						@_computedValue.get() if @_computedValue
					else
						super

		value: (context) ->
			if context == 'sync'
				@_syncValue()
			else
				@get()

		form: (type) ->
			if type == 'display'
				if @_schema.type == 'duration'
					return new ComputedValue =>juration.stringify @get()

			else if type == 'dollarFormat'
				return new ComputedValue => if @get() then '$' + @get().format 2 else '(none)'

			else if type == 'dateFormat'
				return new ComputedValue => @get()?.format '{Mon} {ord}, {year}'

			@

		derive: (type) ->
			@form type


		meta: (query) ->
			if query == 'type' && @_schema.type == 'computed'
				@_schema.dataType
			else
				@_schema[query]

		_syncValue: ->
			if @_schema.type == 'datetime'
				if @_value then @_value.toMysqlFormat() else null
			else if @_schema.type == 'date'
				if @_value then @_value.toMysqlDateFormat() else null
			else if @_schema.type == 'bool'
				if @_value then 1 else 0
			else
				super

	_.extend ModelAttribute::, Observable::

	ModelAttribute