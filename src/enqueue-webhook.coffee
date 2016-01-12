_ = require 'lodash'
async = require 'async'
uuid = require 'uuid'
DeviceManager = require 'meshblu-core-manager-device'
http = require 'http'

class EnqueueWebhooks
  constructor: (options={},dependencies={}) ->
    {@datastore,@jobManager, uuidAliasResolver} = options
    @deviceManager = new DeviceManager {@datastore, uuidAliasResolver}

  _doCallback: (request, code, callback) =>
    response =
      metadata:
        responseId: request.metadata.responseId
        code: code
        status: http.STATUS_CODES[code]
    callback null, response

  do: (request, callback) =>
    {auth, toUuid, fromUuid, messageType} = request.metadata
    message = JSON.parse request.rawData

    @_send {auth, fromUuid, toUuid, messageType, message}, (error) =>
      return callback error if error?
      return @_doCallback request, 204, callback

  _createJob: ({auth, toUuid, fromUuid, messageType, message, options}, callback) =>
    job =
      metadata: {
        auth
        toUuid
        fromUuid
        messageType
        message
        options
        responseId: uuid.v4()
        jobType: 'DeliverWebhook'
      }
      data: message
    @jobManager.createRequest 'request', job, callback

  _send: ({auth, toUuid, fromUuid, messageType, message}, callback) =>
    lookupUuid = fromUuid
    lookupUuid = toUuid if messageType == 'received'

    @deviceManager.findOne {uuid:lookupUuid}, (error, device) =>
      return callback error if error?

      forwarders = device?.meshblu?.forwarders?[messageType]
      return callback null unless forwarders?

      async.eachSeries forwarders, (options, next) =>
        @_createJob {auth, toUuid, fromUuid, messageType, message, options}, next
      , callback

module.exports = EnqueueWebhooks
