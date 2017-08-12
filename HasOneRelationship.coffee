define ['xyzp/Relationship', 'xyzp/PropertyPath', 'xyzp/Observable', 'xyzp/HasManyRelationship'], (Relationship, PropertyPath, Observable, HasManyRelationship) ->
	class HasOneRelationship extends Relationship
		__valueContainer: true

		get: ->
			xyz.ValueCapture.capture @
			@_relInstance

		value: (context) -> 
			xyz.ValueCapture.capture @
			if @_relInstance
				@_relInstance.value context

		form: (context) ->
			form = dataManager.model(@_schema.model)._schema.form?[context]
			if form
				@addObject new PropertyPath(@_instance, "#{@_name}.#{form}")
			else
				@

		meta: (query) ->
			if query in ['model', 'type']
				dataManager.model @_schema.model

		_syncValue: ->
			if @_relInstance
				if @_polymorphic()
					model:@_relInstance._model._name, id:@_relInstance.id
				else
					@_relInstance.id
			else
				null

		_inverseRelation: -> if @_relInstance && @_schema.inverseRelationship then @_relInstance.get @_schema.inverseRelationship

		_polymorphic: ->
			@_schema.model == '*' || _.isArray @_schema.model

		_set: (value, from=null, inverse=true) ->
			if !value? || value instanceof @_instance.constructor
				if inverse
					if @_relInstance && @_schema.inverseRelationship
						@_inverseRelation()._remove @_instance

				@_relInstance = value
				@_fireMutation type:'set', value:value

				if inverse
					if @_relInstance && (inverseRelation = @_inverseRelation())
						if inverseRelation instanceof HasManyRelationship
							inverseRelation._add @_instance
						else
							throw new Error
			else
				if @_polymorphic()
					@_set dataManager.model(value.model).instance value.id
				else
					@_set @model().instance(value)
			true


	_.extend HasOneRelationship::, Observable::
	HasOneRelationship