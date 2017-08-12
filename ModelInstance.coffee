define ['xyzp/ModelProperty', 'xyzp/XValue'], (ModelProperty, XValue) ->
	class ModelInstance
		__value: true
		constructor: (@_model, @id, props, init) ->
			xyz.MutationEvents.pause()
			@_properties = {}

			if !@_isLocal()
				if @_model._schema.id?.type == 'int'
					@id = parseInt @id

			for attrName, attrSchema of @_model._schema.attributes
				continue if attrSchema.parameters || attrSchema.type == 'computed'
				@_properties[attrName] = ModelProperty.create(@, attrName).retain()

			for relName, relSchema of @_model._schema.relationships
				if relSchema.type != 'scope'
					@_properties[relName] = ModelProperty.create(@, relName).retain()


			for relName, relSchema of @_model._schema.relationships
				if relSchema.type == 'scope' && !relSchema.parameters
					@_properties[relName] = ModelProperty.create(@, relName).retain()

			for name, value of props
				@_properties[name]._set value if @_properties[name]


			for attrName, attrSchema of @_model._schema.attributes
				if !attrSchema.parameters && attrSchema.type == 'computed'
					@_properties[attrName] = ModelProperty.create(@, attrName).retain()
					if props[attrName]?
						@_properties[attrName].set props[attrName]



			if init
				@init()

			xyz.MutationEvents.resume()

		init: ->
			for name, prop of @_properties
				prop.init?()

		properties: -> _.keys @_properties

		destruct: ->
			for propName, prop of @_properties
				prop.destruct()

		_isLocal: ->
			@_model._dataManager.isTemporaryId @id

		hasProp: (name) ->
			@_model._schema.attributes?[name] || @_model._schema.properties?[name]

		prop: (name, params...) ->
			if name == 'id'
				new XValue @id
			else if @_properties[name]
				@_properties[name]
			else
				schema = @_model._schema.attributes[name]
				if schema && schema.type == 'computed' && schema.parameters
					prop = ModelProperty.create @, name, params
					prop.init?()
					prop
				else
					throw new Error "no property `#{name}`"

		get: (property, params...) ->
			@prop(property, params...).value()

		_set: (property, value, from=null) ->
			@_properties[property]._set value, from

		set: (property, value) ->
			@prop(property).set value

		setProperties: (properties) ->
			for name,value of properties
				if @hasProp name
					@set name, value
		_recordChange: (type, property, value) ->

		applyChanges: (changes) ->
			if changes == 'delete'
				@_model._delete @
			else
				for propertyPath, propertyChange of changes
					if propertyPath[0] == '@' then continue
					@_set propertyPath, propertyChange, 'applyChanges'

		delete: ->
			@_model.delete @

		_dataManager: ->
			@_model._dataManager

		value: (context) ->
			if valueFunc = @_model._schema.value?[context]
				valueFunc.call @
			else
				@

		form: (context) ->
			if form = @_model._schema.form?[context]
				@prop form
			else
				@

		_syncValues: ->
			values = {}
			for propName, prop of @_properties
				if prop._syncValue && (prop.shouldSync && prop.shouldSync() || !prop.shouldSync)
					values[propName] = prop._syncValue()
			values

		call: (method, params...) ->
			if func =  @_model._schema.methods?[method]
				func.apply @, params
			else if method == 'delete'
				@delete()
			else if @hasProp method
				@get method, params...

		hasMethod: (method) ->
			console.log method
			@_model._schema.methods?[method] || @hasProp method

