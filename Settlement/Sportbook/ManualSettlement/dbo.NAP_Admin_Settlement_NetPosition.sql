/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_NetPosition]
    @MatchId INT
    ,@Bettype SMALLINT
	,@Action VARCHAR(20)
AS
/*	Creator: 20230616@Kathy
	Task: Net postion
	DB: DBTXN/BODB02
	
	Revisions:
		- 20230616@Kathy: Migrate NetPosition API & Services to NAP Settlement System [Redmine:#187311]
*/
BEGIN

    SET NOCOUNT ON;
   
	IF @Action IN ('CAL', 'REFUND')
	BEGIN
		 --update NetPositionQueue with (ROWLOCK, UPDLOCK) set NeedPending=1, ModifiedDate=CURRENT_TIMESTAMP 
    --    where Matchid=@Matchid and Bettype=@bettype
		UPDATE	dbo.NetPositionTrans WITH (ROWLOCK, UPDLOCK) 
			SET	SyncStatus=1
				,IsSettled=1
				,ModifiedDate=CURRENT_TIMESTAMP 
		WHERE	Matchid=@Matchid 
				AND Bettype=@bettype

		UPDATE dbo.BalNetPosition WITH (ROWLOCK, UPDLOCK) 
			SET Debit=0
				,Credit=0
				,ModifiedDate=CURRENT_TIMESTAMP 
		WHERE	Matchid=@Matchid 
				AND Bettype=@bettype
	END
	ELSE IF @Action = 'UNDO'
	BEGIN
		UPDATE	dbo.NetPositionTrans WITH (ROWLOCK, UPDLOCK) 
			SET	SyncStatus=0
				,IsSettled=0
				,ModifiedDate=CURRENT_TIMESTAMP 
		WHERE	Matchid=@Matchid 
				AND Bettype=@bettype
	END
END

