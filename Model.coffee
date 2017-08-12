define ['xyzp/XArray', 'xyzp/XValue', 'xyzp/Observable', 'xyzp/OfflineDB', 'xyzp/util', 'xyzp/FilteredArray', 'xyzp/ComputedValue', 'xyzp/XObject', 'xyzp/ModelInstance', 'xyzp/HasOneRelationship', 'xyzp/HasManyRelationship', 'xyzp/SortedArray'], (XArray, XValue, Observable, OfflineDb, util, FilteredArray, ComputedValue, XObject, ModelInstance, HasOneRelationship, HasManyRelationship, SortedArray) ->
	class Model
		constructor: (@_dataManager, @_name, @_schema) ->
			@_instances = new XArray
			@_instancesById = {}
			@_addedInstances = []

		init: (done) ->
			if @_schema.scopes
				@_scopes = {}
				for name, scope of @_schema.scopes
					if !scope.parameters
						@_scopes[name] = util.objectList new FilteredArray(@_instances, scope.test).retain()

			if @_schema.modelAttributes
				@_attributes = {}
				for name, attribute of @_schema.modelAttributes
					if !attribute.parameters
						do (attribute) =>
							if attribute.prop
								@_attributes[name] = attribute.prop.call(@).retain()
							else
								@_attributes[name] = new ComputedValue(=> attribute.get.call @).retain()

			if @_schema.storage?.localStorage
				data = localStorage.getItem @_schema.storage.localStorage
				if data
					data = JSON.parse data
					if data
						@currentTimetstamp = data.timestamp
						for instance in data.data
							id = instance.id
							delete instance.id
							@_addInstance id, instance
						done()
						return

			if @_schema.storage?.file
				$.get @_schema.storage?.file, ((response) =>
					@currentTimetstamp = response.timestamp
					for instance in response.data
						id = instance.id
						delete instance.id
						@_addInstance id, instance
					done()
				), 'json'
			else
				done()


		scope: (name, params...) ->
			if scope = @_schema.scopes?[name]
				if @_scopes[name]
					@_scopes[name]
				else
					util.objectList new FilteredArray(@_instances, (instance) ->
						scope.test instance, params...
					)

		derive: (name, params...) ->
			if scope = @scope name, params...
				scope
			else
				switch name
					when 'sorted'
						new SortedArray @_instances, (a, b) ->
							util.compare a.get(params[0]), b.get(params[0]), params[1]
					else
						@

		_hasInstance: (id) -> @_instancesById[id]

		_addInstance: (id, props, init) ->
			instance = @_instancesById[id] = new ModelInstance @, id, props, init
			@_addedInstances.push instance
			instance

		_commitInstances: ->
			for instance in @_addedInstances
				@_instances.push instance
				instance.init()
			@_addedInstances = []

		create: (values={}) ->
			instance = @_addInstance @_dataManager.nextTemporaryId(), values, true
			# for propName, propValue of values
			# 	instance._set propName, propValue
			@_dataManager._changes.createInstance 1, @_name, instance.id, instance._syncValues()
			@_dataManager._setObjectForTemporaryId instance.id, instance
			@_commitInstances()
			instance

		delete: (instance) ->
			@_delete instance
			@_dataManager._changes.deleteInstance 1, @_name, instance.id

		_delete: (instance) ->
			for name, prop of instance._properties
				if prop instanceof HasOneRelationship
					if prop._schema.inverseRelationship
						inverseRelation = prop._inverseRelation()
						if inverseRelation instanceof HasManyRelationship
							inverseRelation._remove instance
						else if inverseRelation instanceof HasOneRelationship
							inverseRelation._set null
				else if prop instanceof HasManyRelationship
					if prop._schema.inverseRelationship
						prop.each (relInstance) ->
							inverseRelation = prop._inverseRelation relInstance
							if inverseRelation instanceof HasManyRelationship
								inverseRelation.remove instance, false
							else if inverseRelation instanceof HasOneRelationship
								inverseRelation._set null

	
			for modelName, modelSchema of @_dataManager.schema.models
				if modelSchema.relationships
					for relName, relSchema of modelSchema.relationships
						if relSchema.model == @_name && relSchema.type == 'One' && !relSchema.inverseRelationship
							for instance in @_dataManager.model(modelName).find((inst) -> inst.get(relName) == instance)
								instance.set relName, null


			@_instances.remove instance
			delete @_instancesById[instance.id]
			instance.destruct()

		instance: (id) ->
			@_instancesById[id]

		contains: (instance) -> true

		# forEach: (iter) ->
		# 	@_instances.forEach iter

		findOne: (predicate) ->
			if _.isPlainObject predicate
				values = predicate
				predicate = (instance) ->
					for name, value of values
						if instance.get(name) != value
							return false
					true

			@_instances.findOne predicate

		find: (predicate) ->
			if _.isPlainObject predicate
				values = predicate
				predicate = (instance) ->
					for name, value of values
						if instance.get(name) != value
							return false
					true

			@_instances.find predicate


		call: (method, params...) ->
			if func =  @_schema.modelMethods?[method]
				func.apply @, params
			else if method == 'create'
				@create params...
			else
				throw new Error "no method #{method}"

		hasMethod: (method) ->
			@_schema.modelMethods?[method] || _.isFunction @[method]

		attr: (name, params...) ->
			if !_.isNaN(parseInt name)
				@get name
			else
				if @_attributes[name]
					@_attributes[name].get()
				else if attribute = @_schema.modelAttributes?[name]
					
					if attribute.prop
						attribute.prop.apply(@, params).get()
					else
						attribute.get.apply @, params

		attrCont: (name, params...) ->
			if !_.isNaN(parseInt name)
				new XValue @get name
			else
				r = @_attributes?[name] ? @_scopes?[name]
				if !r
					attribute = @_schema.modelAttributes?[name]
					if attribute
						if attribute.prop
							attribute.prop.apply(@, params)
						else
							new ComputedValue => attribute.get.apply @, params
				else
					r

		updateFromRemote: ->
			$.get @_schema.storage.remote, {timestamp:@currentTimetstamp}, ((response) =>
				if response != 'null'
					localStorage.setItem @_schema.storage.localStorage, response
					response = JSON.parse response
					@currentTimetstamp = response.timestamp

					@sync response.data

			), 'text'


		sync: (data) ->
			instances = {}
			for record in data
				id = record.id
				delete record.id
				instances[id] = true
				if instance = @instance id
					instance.setProperties record
				else
					@_addInstance id, record

			toDelete = []
			@_instances.each (instance) =>
				if !instances[instance.get 'id']
					toDelete.push instance.get 'id'

			for id in toDelete
				@instance(id).delete()

	util.observableProxy Model, '_instances'
	util.arrayProxy Model, '_instances'

	Model