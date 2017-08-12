define ->
	class OfflineDb
		constructor: ->
			request = (indexedDB ? shimIndexedDB).open 'dbms', 1
			request.onsuccess = (e) =>
				@db = e.target.result
				if @readyCbs
					cb() for cb in @readyCbs
					delete @readyCbs

			request.onupgradeneeded = (e) ->
				db = e.target.result
				db.createObjectStore 'instances', keyPath: '_key'
				# db.createObjectStore 'changes', keyPath: 'db'

		available: -> localStorage.getItem('dbName')

		create: (version, clientId, dbName, schema) ->
			localStorage.setItem 'version', version
			localStorage.setItem 'clientId', clientId
			localStorage.setItem 'dbName', dbName
			localStorage.setItem "#{dbName}.schema", JSON.stringify schema

		migrate: (fromVersion, toVersion) ->

		storeChanges: (db, changes) ->
			localStorage.setItem "#{db}.changes", JSON.stringify changes


		storePendingUpdate: (pendingUpdate) ->
			localStorage.setItem 'pendingUpdate', JSON.stringify pendingUpdate

		clearPendingUpdate: ->
			localStorage.removeItem 'pendingUpdate'

		clearChanges: (db) ->
			localStorage.removeItem "#{db}.changes"

		clear: (session) ->
			# @clearChanges()
			# localStorage.clear()
			localStorage.removeItem 'version'
			localStorage.removeItem 'clientId'

			@clearPendingUpdate()

			db = localStorage.getItem('dbName')
			localStorage.removeItem 'dbName'
			
			localStorage.removeItem "#{db}.schema"
			localStorage.removeItem "#{db}.changes"


			(indexedDB ? shimIndexedDB).deleteDatabase 'dbms'


		# addChanges: (db, changes) ->
		# 	changesStore = @db.transaction(['changes'], 'readwrite').objectStore 'changes'
		# 	changesStore.add
		# 		db:	db
		# 		changes: changes


		write: (data, cb) ->
			@ready =>
				allModelData = {}
				resourceChanges = {}

				for changeKey, subChanges of data
					if changeKey[0] == '/'
						resourceChanges[changeKey] = subChanges
					else
						allModelData[changeKey] = subChanges

				instancesStore = @db.transaction(['instances'], 'readwrite').objectStore 'instances'

				for modelName, modelData of allModelData
					for id, instanceChanges of modelData
						do (modelName, id, instanceChanges) =>
							key = "#{modelName}.#{id}"
							if instanceChanges == 'delete'
								instancesStore.delete key
							else
								instancesStore.get(key).onsuccess = (e) =>
									instanceData = e.target.result ? {}
									if !instanceData._key
										instanceData._key = key
										instanceData._model = modelName
										instanceData._id = id
									_.extend instanceData, instanceChanges
									instancesStore.put instanceData

				cb?()

		ready: (cb) ->
			if @db
				cb()
			else
				@readyCbs ?= []
				@readyCbs.push cb

		changeId: (model, id, newId) ->
			@ready =>
				instancesStore = @db.transaction(['instances'], 'readwrite').objectStore 'instances'
				instancesStore.get("#{model}.#{id}").onsuccess = (e) ->
					instanceData = e.target.result
					instancesStore.delete "#{model}.#{id}"
					instanceData._id = newId
					instanceData._key = "#{model}.#{newId}"
					instancesStore.put instanceData

		read: (version, db, cb) ->
			@ready =>
				instancesStore = @db.transaction(['instances'], 'readwrite').objectStore 'instances'
				data = {}
				cursor = instancesStore.openCursor().onsuccess = (e) ->
					cursor = e.target.result
					if cursor
						instance = cursor.value
						delete instance._key
						data[instance._model] ?= {}
						data[instance._model][instance._id] = instance
						delete instance._model
						delete instance._id
						cursor.continue()
					else
						storeVersion = localStorage.getItem 'version'

						if storeVersion != version
							if version == '2'
								if storeVersion == 'v1'
									changes = localStorage.getItem "#{db}.changes"
									if changes
										changes = JSON.parse changes
										localStorage.setItem "#{db}.changes", JSON.stringify 1:changes
							localStorage.setItem 'version', version

						cb
							data:data
							clientId:localStorage.getItem 'clientId'
							schema:JSON.parse localStorage.getItem "#{db}.schema"
							changes:JSON.parse localStorage.getItem "#{db}.changes"
							pendingUpdate:JSON.parse localStorage.getItem 'pendingUpdate'