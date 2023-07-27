/*<info serverAlias="DBSIC-bodb02, DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_TicketVoiding_NetPosition]
	@strTransIds VARCHAR(MAX)
	,@Action VARCHAR(20)
AS
/*	Creator: 20230616@Kathy
	Task: Net postion
	
	Revisions:
		- 20230616@Kathy: Migrate NetPosition API & Services to TVS [Redmine:#189706]
		- 20230727@Kathy: support in-house replicator [Redmine:#191540]
*/
BEGIN

    SET NOCOUNT ON;

	DECLARE @tmpTransIds TABLE (TransId BIGINT)

	INSERT INTO @tmpTransIds (TransId)
	SELECT	[value]
	FROM	STRING_SPLIT(@strTransIds,',')

	IF @Action = 'VOID'
	BEGIN
		UPDATE n
			SET actual_stake=0
				,Payout1=0
				,Payout2=0
				,ModifiedDate=CURRENT_TIMESTAMP
				,SyncStatus = CASE WHEN isSettled = 1 THEN SyncStatus ELSE 0 END
				,RepUpdateTime = SYSDATETIME()
		FROM	dbo.NetPositionTrans n WITH(ROWLOCK, UPDLOCK)	
			INNER JOIN @tmpTransIds t
				ON n.transid = t.transid
	END
	ELSE IF @Action = 'RECOVER'
	BEGIN
		MERGE dbo.NetPositionTrans AS TARGET
		USING (
			SELECT	t.transid
					,b.custid
					,b.matchid
					,b.bettype
					,b.betid
					,actual_stake
					,CASE 
									WHEN betteam='h' 
										THEN actual_stake + stake * (odds - 1)
									ELSE 0 
								END AS Payout1
																							
					,CASE 
									WHEN betteam='a' 
										THEN actual_stake + stake * (odds - 1)
									ELSE 0 
								END AS Payout2				   
			FROM	@tmpTransIds t
				INNER JOIN dbo.bettrans b WITH(NOLOCK)
					ON t.transid = b.transid
		) AS SOURCE
			ON TARGET.transid = SOURCE.transid
		WHEN	MATCHED THEN
			UPDATE 
				SET TARGET.actual_stake = SOURCE.actual_stake
					,TARGET.Payout1 = SOURCE.Payout1
					,TARGET.Payout2 = SOURCE.Payout2
					,TARGET.ModifiedDate = CURRENT_TIMESTAMP
					,TARGET.SyncStatus= CASE WHEN IsSettled = 1 THEN SyncStatus ELSE 0 END
					,TARGET.RepUpdateTime = SYSDATETIME()
		WHEN NOT MATCHED BY TARGET AND SOURCE.betid = 0 THEN
			INSERT (Custid,Transid,Matchid,bettype,actual_stake,Payout1,Payout2,SyncStatus,CreatedDate,ModifiedDate, RepUpdateTime)
				VALUES (SOURCE.CustId, SOURCE.TransId, SOURCE.MatchId, SOURCE.bettype, SOURCE.actual_stake, SOURCE.Payout1, SOURCE.Payout2, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, SYSDATETIME());
	END
END
