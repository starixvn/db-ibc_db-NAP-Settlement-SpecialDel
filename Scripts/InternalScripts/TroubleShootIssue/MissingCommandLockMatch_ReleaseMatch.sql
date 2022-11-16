/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
-- RUN ON DBTRANS/bodb02 or any subDB if missing command

/*
--Sample code to decompress json
DECLARE @Decompress_TransInfoJson NVARCHAR(MAX), @TransInfoJson VARBINARY(MAX)

SET @TransInfoJson = 0x1F8B0800000000000400ED95CB6AC3301045EFB778DD18C9766A3B1FD16C0A5D8410523785424D42EDD045E9BFF76A3C49FC5A749F41083473E665F98236F84184967B850C0512E458F294C1C37179AE47FA0B94240F8CAB2536A23F9688B0222147210BDAB1C407D2F91B21AE9711FC8DF68DD8D57127CC0DFD42851CCFB45352CF5956324DCC9A61BEAEDBB7E47AED34ACBC57BA60AE9BD0FA4AD319DA5C69324B5B566F7196B84F894C849C50A935CEA974D2E564CA8E94931E95FE8FB1BFBBAD17ACF1A4B7D0E0036F5ADFEB245F6A87F32B0E78C74EBF693CD985DEAA38FC92FC5F13A569C234D1D3442967D38469A2AF89D4DE0ED3C44413F6769826869AC8ECEDB8134D6CF107E09BBFA87A0C0000

SET @Decompress_TransInfoJson = CAST(DECOMPRESS(@TransInfoJson) AS NVARCHAR(MAX))

SELECT @Decompress_TransInfoJson

*/

---------------------------- CASE 1: MISSING lock match command OR missing release command ------------------------------
DECLARE @session_id BIGINT, @sitedbgroupid smallint, @matchid INT, @messagetype varchar(200) 

SET @sitedbgroupid = XXXX
if @sitedbgroupid = 1 
	SET @messagetype = 'sitedb1_bet_settle_msg_type'
ELSE IF @sitedbgroupid = 2 
	SET @messagetype = 'sitedb2_bet_settle_msg_type'

SELECT TOP 1 @session_id = SessionId, @matchid = matchid
FROM SiteDB_SettlementLock WITH (NOLOCK)
WHERE SiteDBGroupId = @sitedbgroupid
ORDER BY SessionId

DECLARE @ErrCode INT = 0	 
	,@ErrMsg VARCHAR(300) = '' 

---------------------------- CASE 1.1: MISSING lock match command ------------------------------
EXEC NAP_SettlementService_Calculation
	@SiteDBGroupId = @sitedbgroupid
	,@SessionId	= @session_id
	,@MessageType = @sitedbgroupid
	--,@TransInfo			XML				= NULL
	--,@TransInfoJson		VARBINARY(MAX)	= NULL
	,@TableName = 'SiteDB_SettlementLock' 
	,@MatchId = @matchid
	,@Action = 'I'
	--,@SettlementAction	VARCHAR(20)		= NULL
	--,@TicketType		VARCHAR(1)		= NULL
	,@TotalQueue		= 4
	--,@SettlementProcessingId BIGINT		= 0
	,@ErrCode = @ErrCode OUTPUT
	,@ErrMsg =	@ErrMsg OUTPUT
SELECT @ErrCode, @ErrMsg

---------------------------- CASE 1.2: MISSING lock release match command ------------------------------
EXEC NAP_SettlementService_Calculation
	@SiteDBGroupId = @sitedbgroupid
	,@SessionId	= @session_id
	,@MessageType = @sitedbgroupid
	--,@TransInfo			XML				= NULL
	--,@TransInfoJson		VARBINARY(MAX)	= NULL
	,@TableName = 'SiteDB_SettlementLock' 
	,@MatchId = @matchid
	,@Action = 'D'
	--,@SettlementAction	VARCHAR(20)		= NULL
	--,@TicketType		VARCHAR(1)		= NULL
	,@TotalQueue		= 4
	--,@SettlementProcessingId BIGINT		= 0
	,@ErrCode = @ErrCode OUTPUT
	,@ErrMsg =	@ErrMsg OUTPUT
SELECT @ErrCode, @ErrMsg


GO 
---------------------------- CASE 2: MISSING BOTH lock match command AND missing release command ------------------------------

DECLARE @session_id BIGINT, @sitedbgroupid smallint, @matchid INT, @messagetype varchar(200) 

SET @sitedbgroupid = XXXX

IF @sitedbgroupid = 1 
	SET @messagetype = 'sitedb1_bet_settle_msg_type'
ELSE IF @sitedbgroupid = 2 
	SET @messagetype = 'sitedb2_bet_settle_msg_type'

-- Must input info for @matchid and @sessionid (can get from table SiteDB_SettlementProcessing)
SELECT  @matchid = XXX, @session_id = XXX

-- in case of missing lock match command, push command to lock match
DECLARE @ErrCode INT = 0	 
	,@ErrMsg VARCHAR(300) = '' 

EXEC NAP_SettlementService_Calculation
	@SiteDBGroupId = @sitedbgroupid
	,@SessionId	= @session_id
	,@MessageType = @sitedbgroupid
	--,@TransInfo			XML				= NULL
	--,@TransInfoJson		VARBINARY(MAX)	= NULL
	,@TableName = 'SiteDB_SettlementLock' 
	,@MatchId = @matchid
	,@Action = 'I'
	--,@SettlementAction	VARCHAR(20)		= NULL
	--,@TicketType		VARCHAR(1)		= NULL
	,@TotalQueue		= 4
	--,@SettlementProcessingId BIGINT		= 0
	,@ErrCode = @ErrCode OUTPUT
	,@ErrMsg =	@ErrMsg OUTPUT
SELECT @ErrCode, @ErrMsg


EXEC NAP_SettlementService_Calculation
	@SiteDBGroupId = @sitedbgroupid
	,@SessionId	= @session_id
	,@MessageType = @sitedbgroupid
	--,@TransInfo			XML				= NULL
	--,@TransInfoJson		VARBINARY(MAX)	= NULL
	,@TableName = 'SiteDB_SettlementLock' 
	,@MatchId = @matchid
	,@Action = 'D'
	--,@SettlementAction	VARCHAR(20)		= NULL
	--,@TicketType		VARCHAR(1)		= NULL
	,@TotalQueue		= 4
	--,@SettlementProcessingId BIGINT		= 0
	,@ErrCode = @ErrCode OUTPUT
	,@ErrMsg =	@ErrMsg OUTPUT
SELECT @ErrCode, @ErrMsg
