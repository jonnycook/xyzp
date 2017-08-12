define ['xyzp/XObject'], (XObject) ->
	class ModelProperty extends XObject
		@create: (instance, propertyName, params) ->
			if instance._model._schema.attributes?[propertyName]
				@createAttribute instance, propertyName, params
			else if instance._model._schema.relationships?[propertyName]
				@createRelationship instance, propertyName, params
			else
				throw new Error "invalid property #{propertyName}"

		constructor: (@_instance, @_name, @_schema, @_params) ->
			super

		get: -> @_value
		value: -> @get()

		set: (value) ->
			if @_set(value) == true
				if @_schema.type != 'computed' && !@_instance._model._schema.readonly
					@_instance._dataManager()._changes.setInstanceProperty 1, @_instance._model._name, @_instance.id, @_name, @_syncValue()

		_set: (value) ->
			@_value = value
			true

		shouldSync: -> @_schema.type != 'computed'

		_syncValue: -> @_value
