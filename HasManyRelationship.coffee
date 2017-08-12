define ['xyzp/Relationship', 'xyzp/Observable', 'xyzp/FilteredArray', 'xyzp/SortedArray'], (Relationship, Observable, FilteredArray, SortedArray) ->
	class HasManyRelationship extends Relationship
		xyz.class @, 'list'
		@mixin Observable::

		constructor: (@_instance, @_name, @_schema) ->
			@_instances = []

		value: -> @
		get: (i) ->
			if i == 'length'
				@length()
			else
				@_instances[i]

		_set: (value, from) ->
			instances = []
			if value?
				for instanceValue in value
					if instanceValue instanceof @_instance.constructor
						instances.push instanceValue
					else
						instances.push @model().instance instanceValue

			# TODO: Make compatible with many-to-many
			if @_schema.inverseRelationship
				for instance in _.difference @_instances, instances
					if from != 'applyChanges'
						instance.set @_schema.inverseRelationship, null
					else
						instance.prop(@_schema.inverseRelationship)._set null, from, false
						instance._dataManager()._changes.setInstanceProperty 0, instance._model._name, instance.id, @_schema.inverseRelationship, null

				for instance in _.difference instances, @_instances
					if from != 'applyChanges'
						instance.set @_schema.inverseRelationship, @_instance
					else
						instance.prop(@_schema.inverseRelationship)._set @_instance, from, false
						instance._dataManager()._changes.setInstanceProperty 0, instance._model._name, instance.id, @_schema.inverseRelationship, @_instance.id


			for instance in @_instances
				@_remove instance
		
			for instance in instances
				@_add instance
				
			false

		_syncValue: ->
			instance.id for instance in @_instances

		_inverseRelation: (instance) -> if @_schema.inverseRelationship then instance.get @_schema.inverseRelationship

		_add: (instance) ->
			throw new Error if !instance
			if @_instances.indexOf(instance) == -1
				@_instances.push instance
				@_fireMutation type:'insertion', position:@_instances.length - 1, value:instance

		add: (instance, addToInverse=true) ->
			if @_schema.inverseRelationship
				if instance.prop(@_schema.inverseRelationship)._schema.type == 'One'
					instance.set @_schema.inverseRelationship, @_instance
				else
					if addToInverse
						instance.get(@_schema.inverseRelationship).add @_instance, false
					@_add instance
					@_instance._dataManager()._changes.addToInstanceRelationship 1, @_instance._model._name, @_instance.id, @_name, instance.id

			else
				@_add instance
				@_instance._dataManager()._changes.addToInstanceRelationship 1, @_instance._model._name, @_instance.id, @_name, instance.id

		addNew: (values={}) ->
			@add dataManager.model(@_schema.model).create values


		_remove: (instance) ->
			index = @_instances.indexOf instance
			if index != -1
				@_instances.splice index, 1
				@_fireMutation type:'deletion', position:index, value:instance

		remove: (instance, removeFromInverse=true) ->
			if @_schema.inverseRelationship
				if instance.prop(@_schema.inverseRelationship)._schema.type == 'One'
					instance.set @_schema.inverseRelationship, null
				else
					if removeFromInverse
						instance.get(@_schema.inverseRelationship).remove @_instance, false

					@_remove instance
					@_instance._dataManager()._changes.removeFromInstanceRelationship 1, @_instance._model._name, @_instance.id, @_name, instance.id

			else
				@_remove instance
				@_instance._dataManager()._changes.removeFromInstanceRelationship 1, @_instance._model._name, @_instance.id, @_name, instance.id

		each: (iter) ->
			xyz.ValueCapture.capture @
			iter instance, i for instance, i in @_instances

		forEach: (iter) -> @each iter

		contains: (instance) ->
			@_instances.indexOf(instance) != -1

		length: ->
			xyz.ValueCapture.capture @
			@_instances.length

		scope: (name, params...) ->
			test = @_schema.scopes?[name]
			if test
				xyz.util.objectList new FilteredArray @, (instance) -> test params..., instance

		derive: (name, params...) ->
			if  @_schema.scopes[name]
				@scope name, params...
			else
				switch name
					when 'sorted'
						new SortedArray @, (a, b) ->
							xyz.util.compare a.get(params[0]), b.get(params[0]), params[1]
					else
						@

		findOne: (predicate) ->
			if _.isPlainObject predicate
				values = predicate
				predicate = (instance) ->
					for name, value of values
						if instance.get(name) != value
							return false
					true

			_.find @_instances, predicate

		find: (predicate) ->
			if _.isPlainObject predicate
				values = predicate
				predicate = (instance) ->
					for name, value of values
						if instance.get(name) != value
							return false
					true

			_.filter @_instances, predicate


		exists: (predicate) -> 
			xyz.ValueCapture.capture @
			!!@findOne predicate

		# find: (predicate) ->
		# 	if _.isPlainObject predicate
		# 		values = predicate
		# 		predicate = (instance) ->
		# 			for name, value of values
		# 				if instance.get(name) != value
		# 					return false
		# 			true

		# 	@_instances.find predicate
