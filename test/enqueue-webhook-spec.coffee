{describe,beforeEach,it,expect} = global
uuid            = require 'uuid'
redis           = require 'fakeredis'
mongojs         = require 'mongojs'
Datastore       = require 'meshblu-core-datastore'
JobManager      = require 'meshblu-core-job-manager'
RedisNS         = require '@octoblu/redis-ns'
EnqueueWebhooks = require '../'

describe 'EnqueueWebhooks', ->
  beforeEach (done) ->
    database = mongojs 'enqueue-webhook-test', ['devices']
    @datastore = new Datastore
      database: database
      collection: 'devices'

    database.devices.remove => done()

  beforeEach ->
    @redisKey = uuid.v1()
    pepper = 'im-a-pepper'
    @jobManager = new JobManager
      client: new RedisNS 'ns', redis.createClient(@redisKey)
      timeoutSeconds: 1
      jobLogSampleRate: 1

    @cache = new RedisNS 'ns', redis.createClient(@redisKey)

    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    options = {
      @datastore
      @uuidAliasResolver
      @jobManager
      pepper
      @cache
    }

    @sut = new EnqueueWebhooks options

  describe '->do', ->
    describe 'messageType: broadcast', ->
      describe 'when given a device', ->
        beforeEach (done) ->
          record =
            uuid: 'someone-uuid'
            meshblu:
              forwarders:
                broadcast: [
                  type: 'webhook'
                  url: 'http://requestb.in/18gkt511',
                  method: 'POST'
                ]

          @datastore.insert record, done

        beforeEach (done) ->
          request =
            metadata:
              auth:
                uuid: 'whoever-uuid'
                token: 'some-token'
              responseId: 'its-electric'
              toUuid: 'emitter-uuid'
              fromUuid: 'someone-uuid'
              messageType: 'broadcast'
            rawData: '{"devices":"*"}'

          @sut.do request, (error, @response) => done error

        it 'should return a 204', ->
          expectedResponse =
            metadata:
              responseId: 'its-electric'
              code: 204
              status: 'No Content'

          expect(@response).to.deep.equal expectedResponse

        describe 'the first job', ->
          beforeEach (done) ->
            @jobManager.getRequest ['request'], (error, @request) =>
              done error

          it 'should create a job', ->
            expect(@request.metadata.auth).to.deep.equal uuid: 'someone-uuid', token: 'some-token'
            expect(@request.metadata.jobType).to.equal 'DeliverWebhook'
            expect(@request.metadata.toUuid).to.equal 'emitter-uuid'
            expect(@request.metadata.messageType).to.equal 'broadcast'
            expect(@request.metadata.fromUuid).to.equal 'someone-uuid'
            expect(@request.rawData).to.equal '{"devices":"*"}'
            expect(@request.metadata.options).to.deep.equal
              url: 'http://requestb.in/18gkt511'
              method: 'POST'
              type: 'webhook'

    describe 'messageType: sent', ->
      describe 'when given a device', ->
        beforeEach (done) ->
          record =
            uuid: 'someone-uuid'
            meshblu:
              forwarders:
                sent: [
                  type: 'webhook'
                  url: 'http://requestb.in/18gkt511',
                  method: 'POST'
                ]

          @datastore.insert record, done

        beforeEach (done) ->
          request =
            metadata:
              auth:
                uuid: 'whoever-uuid'
                token: 'some-token'
              responseId: 'its-electric'
              toUuid: 'emitter-uuid'
              fromUuid: 'someone-uuid'
              messageType: 'sent'
            rawData: '{"devices":"*"}'

          @sut.do request, (error, @response) => done error

        it 'should return a 204', ->
          expectedResponse =
            metadata:
              responseId: 'its-electric'
              code: 204
              status: 'No Content'

          expect(@response).to.deep.equal expectedResponse

        describe 'the first job', ->
          beforeEach (done) ->
            @jobManager.getRequest ['request'], (error, @request) =>
              done error

          it 'should create a job', ->
            expect(@request.metadata.auth).to.deep.equal uuid: 'someone-uuid', token: 'some-token'
            expect(@request.metadata.jobType).to.equal 'DeliverWebhook'
            expect(@request.metadata.toUuid).to.equal 'emitter-uuid'
            expect(@request.metadata.messageType).to.equal 'sent'
            expect(@request.metadata.fromUuid).to.equal 'someone-uuid'
            expect(@request.rawData).to.equal '{"devices":"*"}'
            expect(@request.metadata.options).to.deep.equal
              url: 'http://requestb.in/18gkt511'
              method: 'POST'
              type: 'webhook'

      describe 'when given a device with two webhooks of the same type', ->
        beforeEach (done) ->
          record =
            uuid: 'someone-uuid'
            meshblu:
              forwarders:
                sent: [
                  type: 'webhook'
                  url: 'http://requestb.in/18gkt511',
                  method: 'POST'
                ,
                  type: 'webhook'
                  url: 'http://example.com',
                  method: 'GET'
                ]

          @datastore.insert record, done

        beforeEach (done) ->
          request =
            metadata:
              auth:
                uuid: 'whoever-uuid'
                token: 'some-token'
              responseId: 'its-electric'
              toUuid: 'emitter-uuid'
              fromUuid: 'someone-uuid'
              messageType: 'sent'
            rawData: '{"devices":"*"}'

          @sut.do request, (error, @response) => done error

        it 'should return a 204', ->
          expectedResponse =
            metadata:
              responseId: 'its-electric'
              code: 204
              status: 'No Content'

          expect(@response).to.deep.equal expectedResponse

        describe 'the first job', ->
          beforeEach (done) ->
            @jobManager.getRequest ['request'], (error, @request) =>
              done error

          it 'should create a job', ->
            expect(@request.metadata.auth).to.deep.equal uuid: 'someone-uuid', token: 'some-token'
            expect(@request.metadata.jobType).to.equal 'DeliverWebhook'
            expect(@request.metadata.toUuid).to.equal 'emitter-uuid'
            expect(@request.metadata.messageType).to.equal 'sent'
            expect(@request.metadata.fromUuid).to.equal 'someone-uuid'
            expect(@request.rawData).to.equal '{"devices":"*"}'
            expect(@request.metadata.options).to.deep.equal
              url: 'http://requestb.in/18gkt511'
              method: 'POST'
              type: 'webhook'

          describe 'the second job', ->
            beforeEach (done) ->
              @jobManager.getRequest ['request'], (error, @request) =>
                done error

            it 'should create another job', ->
              expect(@request.metadata.auth).to.deep.equal uuid: 'someone-uuid', token: 'some-token'
              expect(@request.metadata.jobType).to.equal 'DeliverWebhook'
              expect(@request.metadata.toUuid).to.equal 'emitter-uuid'
              expect(@request.metadata.messageType).to.equal 'sent'
              expect(@request.metadata.fromUuid).to.equal 'someone-uuid'
              expect(@request.rawData).to.equal '{"devices":"*"}'
              expect(@request.metadata.options).to.deep.equal
                url: 'http://example.com'
                method: 'GET'
                type: 'webhook'

    describe 'messageType: received', ->
      beforeEach (done) ->
        record =
          uuid: 'emitter-uuid'
          meshblu:
            forwarders:
              received: [
                type: 'webhook'
                url: 'http://requestb.in/18gkt511',
                method: 'POST'
              ]

        @datastore.insert record, done

      beforeEach (done) ->
        request =
          metadata:
            auth:
              uuid: 'whoever-uuid'
              token: 'some-token'
            responseId: 'its-electric'
            toUuid: 'emitter-uuid'
            fromUuid: 'someone-uuid'
            messageType: 'received'
          rawData: '{"devices":["emitter-uuid"]}'

        @sut.do request, (error, @response) => done error

      it 'should return a 204', ->
        expectedResponse =
          metadata:
            responseId: 'its-electric'
            code: 204
            status: 'No Content'

        expect(@response).to.deep.equal expectedResponse

      describe 'the first job', ->
        beforeEach (done) ->
          @jobManager.getRequest ['request'], (error, @request) =>
            done error

        it 'should create a job', ->
          expect(@request.metadata.auth).to.deep.equal uuid: 'emitter-uuid', token: 'some-token'
          expect(@request.metadata.jobType).to.equal 'DeliverWebhook'
          expect(@request.metadata.toUuid).to.equal 'emitter-uuid'
          expect(@request.metadata.messageType).to.equal 'received'
          expect(@request.metadata.fromUuid).to.equal 'someone-uuid'
          expect(@request.rawData).to.equal '{"devices":["emitter-uuid"]}'
          expect(@request.metadata.options).to.deep.equal
            url: 'http://requestb.in/18gkt511'
            method: 'POST'
            type: 'webhook'

    describe 'messageType: broadcast with new style hooks', ->
      beforeEach (done) ->
        record =
          uuid: 'emitter-uuid'
          meshblu:
            forwarders:
              broadcast:
                sent: [
                  type: 'webhook'
                  url: 'http://requestb.in/18gkt511',
                  method: 'POST'
                ]

        @datastore.insert record, done

      beforeEach (done) ->
        request =
          metadata:
            auth:
              uuid: 'whoever-uuid'
              token: 'some-token'
            responseId: 'its-electric'
            toUuid: 'emitter-uuid'
            fromUuid: 'emitter-uuid'
            messageType: 'broadcast'
          rawData: '{"devices":["emitter-uuid"]}'

        @sut.do request, (error, @response) => done error

      it 'should return a 204', ->
        expectedResponse =
          metadata:
            responseId: 'its-electric'
            code: 204
            status: 'No Content'

        expect(@response).to.deep.equal expectedResponse

      describe 'the first job', ->
        beforeEach (done) ->
          @jobManager.getRequest ['request'], (error, @request) =>
            done error

        it 'should not create a job', ->
          expect(@request).not.to.exist

  describe '->getUniqueForwarders', ->
    describe 'when there are duplicates', ->
      beforeEach ->
        device =
          meshblu:
            forwarders:
              'some-type': [
                { method: 'UNIQUE', url: 1 }
                { method: 'UNIQUE', url: 1 }
                { method: 'UNIQUE', url: 2 }
                { method: 'UNIQUE', url: 2 }
              ]
        @forwarders = @sut.getUniqueForwarders { device, messageType: 'some-type' }

      it 'should have unique forwarders', ->
        expect(@forwarders).to.deep.equal [
          { method: 'UNIQUE', url: 1 }
          { method: 'UNIQUE', url: 2 }
        ]

    describe 'when there are no dups', ->
      beforeEach ->
        device =
          meshblu:
            forwarders:
              'some-type': [
                { method: 'UNIQUE', url: 1 }
                { method: 'UNIQUE', url: 2 }
              ]
        @forwarders = @sut.getUniqueForwarders { device, messageType: 'some-type' }

      it 'should have unique forwarders', ->
        expect(@forwarders).to.deep.equal [
          { method: 'UNIQUE', url: 1 }
          { method: 'UNIQUE', url: 2 }
        ]

    describe 'when there are no forwarders', ->
      beforeEach ->
        device =
          meshblu: {}
        @forwarders = @sut.getUniqueForwarders { device, messageType: 'some-type' }

      it 'should have unique forwarders', ->
        expect(@forwarders).to.be.null

    describe 'when the forwarders are not an array', ->
      beforeEach ->
        device =
          meshblu:
            forwarders:
              'some-type': {'oh': 'no'}
        @forwarders = @sut.getUniqueForwarders { device, messageType: 'some-type' }

      it 'should have unique forwarders', ->
        expect(@forwarders).to.be.null
