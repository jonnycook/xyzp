define ['xyzp/OfflineDB', 'xyzp/util', 'xyzp/FilteredArray', 'xyzp/ComputedValue', 'xyzp/Model', 'xyzp/ModelProperty', 'xyzp/ModelAttribute', 'xyzp/HasOneRelationship', 'xyzp/HasManyRelationship', 'xyzp/ModelInstance', 'xyzp/PagedList', 'xyzp/SortedArray', 'xyzp/CounterCall', 'xyzp/DataChanges'], (OfflineDb, util, FilteredArray, ComputedValue, Model, ModelProperty, ModelAttribute, HasOneRelationship, HasManyRelationship, ModelInstance, PagedList, SortedArray, CounterCall, DataChanges) ->
	debugWindow = (content) ->
		w = window.open()
		# $(w.document.body).html(content);

		w.document.body.innerHTML = content


	xyz.XArray.derive.paged = (array, pageCount) -> new PagedList array, pageCount

	util.objectList.derivations =
		sorted: (array, prop, order) ->
			new SortedArray array, (a, b) ->
				util.compare a.get(prop), b.get(prop), order

	_.extend ModelProperty,
		createAttribute: (instance, propertyName, params) ->
			schema = instance._model._schema.attributes[propertyName]
			if schema.attr
				schema.attr.apply instance, params
			else
				new ModelAttribute instance, propertyName, schema, params
		createRelationship: (instance, propertyName, params) ->
			schema = instance._model._schema.relationships[propertyName]
			switch schema.type
				when 'One'
					new HasOneRelationship instance, propertyName, schema, params
				when 'Many'
					new HasManyRelationship instance, propertyName, schema, params
				when 'scope'
					new FilteredArray instance.get(schema.relationship), schema.test

	class DataManager
		_parseJson: (json) ->
			try
				JSON.parse json
			catch e
				debugWindow json if @opts.env == 'dev'
				# console.log json
				# Raven.captureException e,
				throw e

		constructor: (@clientVersion, @version, @schemaVersion, @dbName, @mainResource, @server, @transport, @opts={}) ->
			@_models = {}
			@_resources = {}
			@_nextTemporaryId = 0
			@_temporaryIdObjects = {}

			@offline = new xyz.XValue().retain()
			@status = new xyz.XValue().retain()

			@connected = new xyz.XValue(false).retain()

			@_now = new xyz.XValue(new Date).retain()
			setInterval (=>
				@_now.set new Date()
			), 1000

			@today = new xyz.XValue(new Date).retain()
			setInterval (=>
				now = new Date()
				if @today.get().toLocalMysqlDateFormat() != now.toLocalMysqlDateFormat()
					@today.set now
			), 1000*60



			@transport.onUpdate = (update) =>
				@applyChanges update.data
				@transport.sendMessage ['U', [update.id]], (error) =>
					if error
						@_onError error

			@transport.onOpen = =>
				@_isConnected = true
				@connected.set true

			@transport.onClose = =>
				@connected.set false
				if @_wantsConnection
					if @opts.offline
						@_setOffline true
						if !OFFLINE
							setTimeout (=>@connect()), 1000
					else
						if !@_isConnected
							# alert 'Failed to connect with server. Please try again later.'
						else
							@_isConnected = false
							@reload = true
							# alert 'Connection with server was interrupted. Please reload page.'

			@transport.onSendStart = =>
				@status.set 'sending'

			@transport.onSendFinished = =>
				@status.set 'finished'
				setTimeout (=>
					if @status.get() == 'finished'
						@status.set ''
				), 3000

			if @opts.offline
				@offlineDb = new OfflineDb

			@_changes = new DataChanges (changes, done) =>
				console.log changes

				doneCounter = new CounterCall done

				if @offlineDb
					doneCounter.inc()
					@offlineDb.write changes[0], ->
						doneCounter.call()

				if @_offline
					if @offlineDb
						# @offlineDb.addChanges @dbName, changes
						@offlineDb.storeChanges @dbName, @_changes._changes
				else
					if !@_pendingUpdate && changes[1]
						@_sendUpdate changes[1]
						@_changes.clear()
						if @offlineDb
							@offlineDb.clearChanges @dbName

				doneCounter.end()

		_setOffline: (offline) ->
			@_offline = offline
			@offline.set offline

		now: -> @_now.get()

		transaction: (block) ->
			xyz.MutationEvents.pause()
			block()
			xyz.MutationEvents.resume()

		_connect: (sync, cb) ->
			# console.log 'sdf'
			for name, model of @_models 
				if model._schema.storage?.remote
					model.updateFromRemote()



			@_wantsConnection = true
			console.log 'connecting...'
			@transport.init @version, @clientId, @dbName, @schema.version, (success) =>
				if success
					cb? 'init'
					console.log 'done connecting'
					if sync
						@_pull =>
							@_push ->
								cb? 'done'
				else
					cb? 'offline'



		connect: (cb) ->
			if @offlineDb && @_offline
				@_connect true, (state) =>
					if state == 'init'
						@_setOffline false
					else if state == 'done'
						cb?()

			# else
			# 	@_initClientId =>
			# 		@_initSchema =>
			# 			@_init()
			# 			if @offlineDb
			# 				@offlineDb.create @clientId, @dbName, @schema

			# 			@transport.init @clientId, @dbName, =>
			# 				@resource @mainResource, =>
			# 					cb()


		_push: (cb) ->
			if @_pendingUpdate
				@_sendChanges @_pendingUpdate, (response) =>
					delete @_pendingUpdate
					if @offlineDb
						@offlineDb.clearPendingUpdate()
					@_push cb
			else
				changes = @_changes._changes?[1]
				@_changes.clear()
				if changes
					@_sendUpdate changes, =>
						if @offlineDb
							@offlineDb.clearChanges @dbName
						cb?()
				else
					cb?()

		_sendUpdate: (changes, cb) ->
			if !_.isEmpty changes
				throw new Error() if @_pendingUpdate
				@_pendingUpdate =
					id: Math.random()
					data:changes

				if @offlineDb
					@offlineDb.storePendingUpdate @_pendingUpdate

				@_sendChanges @_pendingUpdate, (response) =>
					delete @_pendingUpdate
					if @offlineDb
						@offlineDb.clearPendingUpdate()
					cb?()
			else
				cb?()


		_sendChanges: (changes, cb) ->
			console.log changes
			if !_.isEmpty changes
				@transport.sendMessage ['u', JSON.stringify changes], (error, response) =>
					if error
						@_onError error

					else
						response = @_parseJson response
						# console.log response
						if response.mapping
							for temporaryId, newId of response.mapping
								object = @_temporaryIdObjects[temporaryId]
								if object instanceof ModelInstance
									if @offlineDb
										@offlineDb.changeId object._model._name, object.id, newId

									object.id = newId
									object._model._instancesById[newId] = object
									delete object._model._instancesById[temporaryId]
					cb()
			else
				cb()


		_init: (cb) ->
			for modelName, modelSchema of @schema.models
				@_models[modelName] = new Model @, modelName, modelSchema


			count = 0
			done = false
			for modelName, model of @_models
				++count
				model.init ->
					count--
					if done && !count
						cb()

			done = true
			if !count
				cb()


		isTemporaryId: (id) -> id[0] == '$'

		nextTemporaryId: -> '$' + @_nextTemporaryId++

		_setObjectForTemporaryId: (temporaryId, object) ->
			@_temporaryIdObjects[temporaryId] = object

		model: (modelName) ->
			@_models[modelName]

		applyChanges: (changes, writeToOffline=true) ->
			xyz.MutationEvents.pause()
			console.log 'applyingChanges', changes
			modelChanges = {}
			resourceChanges = {}

			for changeKey, subChanges of changes
				if changeKey[0] == '/'
					resourceChanges[changeKey] = subChanges
				else
					modelChanges[changeKey] = subChanges

			for modelName, modelData of modelChanges
				model = @_models[modelName]
				for id, instanceData of modelData
					if instanceData != 'delete' && !model._hasInstance id
						model._addInstance id, {}, false

			for modelName, modelData of modelChanges
				model = @_models[modelName]
				for id, instanceData of modelData
					instance = model.instance id
					if instanceData == 'delete' && !instance
						continue
					instance.applyChanges instanceData

			for modelName, model of @_models
				model._commitInstances()

			if @offlineDb && writeToOffline
				@offlineDb.write changes

			xyz.MutationEvents.resume()

		_addResource: (resource) ->
			@applyChanges resource.data
			if resource.type == 'model'
				@model(resource.model).instance(resource.id)

		_onError: (error) ->
			alert 'There was an error communicating with the server. The application will now reload.'
			@reset()
			document.location.reload()


		resource: (resourcePath, cb) ->
			if @_resources[resourcePath]
				cb @_resources[resourcePath]
			else
				@transport.sendMessage ['g', resourcePath], (error, resource) =>
					if error
						@_onError error
						cb()
					else
						cb @_resources[resourcePath] = @_addResource @_parseJson resource

		_initClientId: (cb) ->
			client =
				opts:terminateOnDisconnect:if @opts.offline then 0 else 1
				token:@opts.token

			if @opts.client
				_.merge client, @opts.client


			$.get "#{@server}/#{@version}/core/registerClient.php", {client:JSON.stringify client},
				(response) =>
					@clientId = response.id
					@opts.onClientId.call @, @clientId if @opts.onClientId
					console.log 'new client', @clientId
					cb()
				'json'

		_initSchema: (cb) ->
			# if @schema
			# 	cb()
			# else
			# 	if @opts.offline
			# 		@schema = localStorage.getItem "#{@dbName}.schema"
			# 		if @schema
			# 			cb()
			# 			return

				$.get("#{@server}/#{@version}/core/main.php", schema:1, db:@dbName, schemaVersion:@schemaVersion, ((schema) =>
					@_setSchema schema
					# if @opts.offline
					# 	localStorage.setItem "#{@dbName}.schema", schema
					cb()
				), 'json').error (response, type, responseText) =>
					console.error 'Failed to get schema'
					debugWindow response.responseText if @opts.env == 'dev'

		_setSchema: (schema) ->
			@schema = _.clone schema
			if @opts.schemaMods
				_.merge @schema, @opts.schemaMods

		_pull: (cb) ->
			console.log 'pulling'
			@transport.sendMessage ['q'], (error, updates) =>
				if error
					@_onError error
				else
					console.log 'pulled updates', updates
					updates = @_parseJson updates
					if updates
						ids = []
						for update in updates
							ids.push update.id
							@applyChanges update.data
						@transport.sendMessage ['U', ids], (error) =>
							if error
								@_onError error

				cb()


		reset: ->
			if @offlineDb
				@offlineDb.clear()

		clearToken: (cb) ->
			@setClientParam 'token', null, cb

		setClientParam: (key, value, cb) ->
			@transport.sendMessage ['c', key, JSON.stringify value], (error, response) =>
				if error
					@_onError error
				cb? response

		terminateClient: (cb) ->
			$.get "#{@server}/#{@version}/core/terminateClient.php", {clientId:@clientId}, cb

		init: (cb) ->
			if @offlineDb && @offlineDb.available()
				@offlineDb.read @clientVersion, @dbName, (data) =>
					if data.schema.version != @schemaVersion
						console.log 'schema out of date'
						@_changes._changes = data.changes ? {}
						@_pendingUpdate = data.pendingUpdate
						@transport.init @version, data.clientId, @dbName, data.schema.version, (success) =>
							if success
								console.log 'pushing'
								@_push =>
									@offlineDb.clear()
									@init cb
							else
								cb? false, 'outdatedSchemaNoConnection'

					else
						@clientId = data.clientId
						@_setSchema data.schema
						@_changes._changes = data.changes ? {}
						@_pendingUpdate = data.pendingUpdate

						console.log data

						getRel = (model, id, name, instance) =>
							relSchema = @schema.models[model].relationships[name]
							if @schema.models[relSchema.model].relationships[relSchema.inverseRelationship]?.type == 'One'
								rel = []
								for instanceId, instanceData of data.data[relSchema.model]
									if instanceData[relSchema.inverseRelationship] == id
										rel.push instanceId
								rel
							else
								_.filter instance[name], (id) -> data.data[relSchema.model]?[id]

						# resolvedData = {}
						for model, modelData of data.data
							modelSchema = @schema.models[model]
							if modelSchema.relationships
								# console.log model, modelSchema.relationships
								for id, instance of modelData
									for name,rel of modelSchema.relationships
										switch rel.type
											when 'Many'
												instance[name] = getRel model, id, name, instance

											when 'One'
												if !data.data[rel.model]?[instance[name]]
													delete instance[name]


						@_init =>

							# TODO: Figure out if there's a better way to do this
							@_changes.disable()
							@applyChanges data.data, false
							@_changes.enable()

							if !@_offline
								@_connect true

							cb? true

							@opts.onClientId.call @, @clientId if @opts.onClientId
			else
				@_initClientId =>
					@_initSchema =>
						@_init =>
							if @offlineDb
								@offlineDb.create @clientVersion, @clientId, @dbName, @schema
							@_connect false, (state) =>
								if state != 'offline'
									@resource @mainResource, ->
										cb? true
								else
									cb? false

