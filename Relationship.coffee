define ['xyzp/ModelProperty'], (ModelProperty) ->
	class Relationship extends ModelProperty
		model: ->
			modelName = @_instance._model._schema.relationships[@_name].model
			@_instance._model._dataManager.model(modelName)
