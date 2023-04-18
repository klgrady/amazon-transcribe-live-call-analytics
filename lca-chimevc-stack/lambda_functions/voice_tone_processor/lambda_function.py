import json
import boto3
import datetime
import os

KINESIS_STREAM_NAME = os.environ["KINESIS_STREAM_NAME"]
TRANSCRIBER_CALL_EVENT_TABLE_NAME = os.environ["TRANSCRIBER_CALL_EVENT_TABLE_NAME"]

chimeClient = boto3.client('chime-sdk-voice')
kdsClient = boto3.client('kinesis')
dynamoClient = boto3.resource('dynamodb')
dynamoTable = dynamoClient.Table(TRANSCRIBER_CALL_EVENT_TABLE_NAME)

voiceTaskCache = {}
callDetailCache = {}

def get_call_record(callId):
    if callId in callDetailCache:
        return callDetailCache[callId]
    
    pk = "cd#" + callId
    sk = "BOTH"
    response = dynamoTable.get_item(
        Key = {
            'PK': pk,
            'SK': sk
        }
    )
    callDetailCache[callId] = response['Item']
    return response['Item']

def put_voice_task(voiceToneAnalysisTaskId, callId):
    pk = "vta#" + voiceToneAnalysisTaskId
    sk = callId
    # TODO: calculate TTL
    response = dynamoTable.put_item(
        Item = {
            'PK': pk,
            'SK': 'VTA',
            'VoiceToneAnalysisTaskId': voiceToneAnalysisTaskId,
            'CallId': callId
        }
    )
    # save to local cache
    voiceTaskCache[voiceToneAnalysisTaskId] = callId
    return

def get_callId_for_voiceTask(voiceToneAnalysisTaskId):
    if voiceToneAnalysisTaskId in voiceTaskCache:
        return voiceTaskCache[voiceToneAnalysisTaskId]
    
    pk = "vta#" + voiceToneAnalysisTaskId
    response = dynamoTable.get_item(
        Key = {
            'PK': pk,
            'SK': 'VTA'
        }
    )
    
    callId = response['Item']['CallId']
    voiceTaskCache[voiceToneAnalysisTaskId] = callId
    
    return callId

def lambda_handler(event, context):
    print(json.dumps(event))
    detail = event['detail']
    
    if detail['detailStatus'] == 'AnalyticsReady':
        response = chimeClient.start_voice_tone_analysis_task(
            VoiceConnectorId=detail['voiceConnectorId'],
            TransactionId=detail['transactionId'],
            LanguageCode='en-US',
            ClientRequestToken=detail['callId']
        )
        
        voiceToneAnalysisTaskId = response['VoiceToneAnalysisTask']['VoiceToneAnalysisTaskId']
        print("RESPONSE TASK_ID: " + voiceToneAnalysisTaskId)
        put_voice_task(voiceToneAnalysisTaskId, detail['callId'])
        
    if detail['detailStatus'] == 'VoiceToneAnalysisSuccessful':
        callId = get_callId_for_voiceTask(detail['taskId'])
        callRecord = get_call_record(get_callId_for_voiceTask(detail['taskId']))
        callData = json.loads(callRecord['CallData'])
        
        callStartTimeStr = callData['callStreamingStartTime']
        callStartTime = datetime.datetime.strptime(callStartTimeStr,'%Y-%m-%dT%H:%M:%S.%fZ')
        
        timestampStr = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%SZ')
        
        participant = 'CALLER_VOICE_SENTIMENT' if detail['isCaller'] != True else 'AGENT_VOICE_SENTIMENT'
        sentiment = detail['voiceToneAnalysisDetails']['currentAverageVoiceTone']['voiceToneLabel'].upper()
        
        segmentStartTimeStr = detail['voiceToneAnalysisDetails']['currentAverageVoiceTone']['startTime']
        segmentStartTime = datetime.datetime.strptime(segmentStartTimeStr,'%Y-%m-%dT%H:%M:%S.%fZ')
        
        segmentEndTimeStr = detail['voiceToneAnalysisDetails']['currentAverageVoiceTone']['endTime']
        segmentEndTime = datetime.datetime.strptime(segmentEndTimeStr,'%Y-%m-%dT%H:%M:%S.%fZ')

        endMillis = (segmentEndTime - callStartTime).total_seconds() * 1000
        #startMillis = (segmentStartTime - callStartTime).total_seconds() * 1000
        startMillis = endMillis - 5000
        
        putObj = {
            'EventType': 'ADD_TRANSCRIPT_SEGMENT',
            'CallId': callId,
            'UtteranceEvent': {
                'UtteranceId': event['id'][3:],
                'ParticipantRole': participant,
                'isPartial': False,
                'Transcript':'voice tone',
                'Sentiment': sentiment,
                'BeginOffsetMillis': startMillis,
                'EndOffsetMillis': endMillis,
            },
            'CreatedAt': timestampStr,
            'UpdatedAt': timestampStr
        };
        
        print(json.dumps(putObj))
        
        response = kdsClient.put_record(
            StreamName=KINESIS_STREAM_NAME,
            Data=json.dumps(putObj),
            PartitionKey=callId,
        )
        
    return
