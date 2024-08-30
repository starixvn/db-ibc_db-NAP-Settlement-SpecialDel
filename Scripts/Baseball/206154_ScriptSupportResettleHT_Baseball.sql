/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/

/*
    Created by: 20240830@Helen
    Task: Script to support settle HT baseball [Redmine:#206154]
    DB: DBSIG/bodb02

*/
DECLARE @MatchId INT = xxxxx
	, @HomeValue VARCHAR(2000) = 'x'
	, @AwayValue VARCHAR(2000) ='y' 
DECLARE @IsReSettledTickets BIT = 1
	, @DeterminedType INT	= 0
	, @strTransIds VARCHAR(MAX)	= ''
	, @ActionID			INT = 100
	, @BroadcastSessionId	VARCHAR(50)	= NULL
	, @IsCalculateBalance		BIT = 1 ---calculate balance inside SP calculate transid
	, @ErrCode			INT				= 0	
	, @ErrMessage 			NVARCHAR(200)	= '' 
CREATE TABLE #tmpTransID (TransID BIGINT,CustID INT, modds SMALLMONEY DEFAULT 0, OddsType SMALLINT, srecommend INT,bettype SMALLINT, IsMarked BIT, BetdaqId BIGINT, DeadHeat TINYINT, currentStatuswinlost TINYINT)
CREATE CLUSTERED INDEX IX_tmpTrans_modds ON #tmpTransID (modds DESC, custID,TransID);

DECLARE @tmpSelectedRID TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000),
								BetType SMALLINT, BetID BIGINT, pfID SMALLINT,SDTpfId SMALLINT, RoundID VARCHAR(10), OrdNo SMALLINT,
								isFinal BIT, RoundName VARCHAR(20), GroupType VARCHAR(2), OddsType SMALLINT, RefResourceId VARCHAR(20), IsWeb BIT
								,PRIMARY KEY (BetType,BetID))

INSERT INTO @tmpSelectedRID(pfID,BetType, ResourceID, HomeValue, AwayValue,  BetID, OddsType)
SELECT	10,	7, '01', @HomeValue, @AwayValue, 0, 0
UNION ALL
SELECT	3,	8 , '01', @HomeValue, @AwayValue, 0, 0
UNION ALL
SELECT	5,	15, '01', @HomeValue, @AwayValue, 0, 1
UNION ALL
SELECT	20,	21, '01', @HomeValue, @AwayValue, 0, 0
UNION ALL
SELECT	2,	12, '01', @HomeValue, @AwayValue, 0, 0

INSERT INTO #tmpTransID(TransID, CustID, modds, OddsType, srecommend, bettype, IsMarked, BetdaqId, DeadHeat, currentStatuswinlost)
SELECT	b.transid
		,b.CustID
		,m.modds
		,sr.OddsType
		,b.srecommend, b.bettype, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS IsMarked
		,ISNULL(b.betdaqid,0)
		,m.DeadHeat
		,b.statuswinlost
FROM bettrans b WITH (NOLOCK)
	OUTER APPLY (
					SELECT TOP (1) mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transId
	) mt
	CROSS APPLY(
					SELECT TOP 1 pfID, HomeValue, AwayValue, t.OddsType
					FROM @tmpSelectedRID t
					WHERE b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID) 
				) sr
	CROSS APPLY dbo.f_Set_Calculate_modds(sr.pfID, b.betteam, b.hdp1, b.hdp2, sr.HomeValue, sr.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc, b.betid) m
WHERE b.matchid = @MatchId
	--AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	AND b.statusID NOT IN (101)
	AND 1 = CASE 
				WHEN ISNULL(b.betdaqid,0) = -2 THEN 1
				WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
				WHEN @IsReSettledTickets = 1 THEN 1
				ELSE 0
			END
	AND b.bettype IN (7,8,15,21,12)

--filter selectedRID by current Profile and BetType
SET @strTransIds = (SELECT transid	AS '@t'
					,modds	AS '@m'
					,OddsType	AS '@ot'
					,srecommend AS '@sr'
					,bettype AS '@bt'
					,IsMarked AS '@im'
					,DeadHeat AS '@dh'
			FROM #tmpTransID
			FOR XML PATH('r'), ROOT( 'root' ))

EXEC dbo.NAP_Admin_Calculate_TransID
	@transIds   			= @strTransIds						  
	,@matchid				= @matchid
	,@ActionId			= @ActionId
	,@IsCalculateBalance	= @IsCalculateBalance
    ,@BroadcastSessionId  = @BroadcastSessionId
	,@ErrCode				= @ErrCode OUTPUT
	,@ErrMessage			= @ErrMessage OUTPUT

