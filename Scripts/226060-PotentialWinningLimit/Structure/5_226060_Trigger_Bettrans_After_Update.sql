/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

---run on SiteDB03 Only

--A): alter trigger case:

	--1)check long running
	--2)set lock timeout
	--3)set deadlock priority low
	--4)GO
	--5)alter trigger

--B): alter table case:

	--1)check long running
	--2)set lock timeout
	--3)set deadlock priority low
	--4)alter command

--#1)
DECLARE @__messageInfo VARCHAR(200)
__tryAgain:
IF (dbo.f_dba_check_long_holding_locks ('bettrans' /*tableName*/, getdate() /*current time*/, 1000 /*long query exceeded 1s*/, 1 /*retry in 1 min*/)) = 1
BEGIN
	SELECT @__messageInfo = 'curdt: ' + convert(varchar(50), getdate(), 121) + ' | Too many long running operations on the table. Retry attempt again ...'
	RAISERROR(@__messageInfo, 0, 1) WITH NOWAIT
	WAITFOR DELAY '00:00:00:333' --wait for alter schema
	GOTO __tryAgain
END


--doing.... 
--#2 #3)
SET LOCK_TIMEOUT 1024
SET DEADLOCK_PRIORITY LOW

--#4
GO
ALTER TRIGGER [dbo].[Bettrans_After_Update]
   ON [dbo].[bettrans]
   AFTER UPDATE
AS 
/*
    Created: Joe@
    DB: DBSIG.bodb02
    Task: 
    Revision:
        - 20200922@Kathy: Add column matchid, statusid, Settlement, smawinlost, smacomm [Redmine:#138552]
        - 20201007@Sol: Add new action id due to code changed - [Redmine:#142346]
        - 20201119@Kathy: Add column modds [Redmine:#142346]
        - 20201119@Sol: modified action text - [Redmine:#142346]
        - 20210309@Kathy: Allow null for bettype,actual_stake, winlost, playercomm [Redmine:#138552]
        - 20220217@Kathy: - Alpha - Avoid confusion when event date is moved [Redmine:#167296]
                          - Cash Out - Add 2 new Action ID [Redmine:#168627]
        - 20220329@Kathy: Wrong actionId when undo ticket [Redmine:168627]
        - 20220505@Louisa: For parlay and Outright, only capture when new winlostdate > old winlostdate [Redmine:#167296]
        - 20220526@Louisa: Do not capture when ticket change status from Running to Settled [Redmine:#167296]
        - 20220629@Helen: BalanceRecord -> wrong capture balance change and new balance when resettle tickets AE-Sexy product [Redmine:#173971]
        - 20220912@Helen: clone trigger from db05 to sitedb for scaleout project [176932]
		- 20230615@Kathy: check ticket was moved winlostdate, add column winlostdate, refno [Redmine:#181595]
		- 20230808@Kathy: Filter out Recover Bets [Redmine:#191844]
		- 20240716@July: Update SettlementType for case change WinLostDate (move Event) OR MatchID (case Move ticket) [Redmine:#203615]
		- 20250416@Louisa:  capture for bef_statusid, bef_winlost into table balancetrigger [Redmine:#226060]
*/

BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;
    DECLARE @bettype SMALLINT, @IsLC_RnG BIT = 0, @IsTransLog BIT = 0
    SET @bettype = (SELECT TOP 1 bettype FROM inserted)

    SET @IsLC_RnG = (SELECT TOP 1 1  FROM SportBettypeMatrix WITH (NOLOCK)
                    WHERE RefTable IN (1,2) AND bettype = @bettype
                    )
    IF @IsLC_RnG = 1 RETURN

	SET @IsTransLog = (SELECT TOP 1 1 FROM SportBettypeMatrix WITH (NOLOCK)
                        WHERE RefTable in (3) and bettype = @bettype
						)

    -- Insert statements for trigger here
    INSERT INTO dbo.BalanceTrigger (custid, transid, bettype, actual_stake, winlost, playercomm, ActionDate, 
        ActionID, [Action],
        BalanceChanged,
        MatchId, StatusId, SettlementType, swinlost, mwinlost, awinlost, scomm, acomm, comm, modds, winlostdate, refno,  bef_statusid, bef_winlost)
    SELECT
        -- if inserted.custid = 0, this should be VOID + Hidden
        -- if deleted.custid = 0, this may be Bet Recover
        case when i.custid =0 then d.custid else i.custid end,
        i.transid, i.bettype, i.actual_stake, isnull(i.winlost,0) as winlost, isnull(i.playercomm,0) as playercomm, CURRENT_TIMESTAMP, 

        CASE 
            WHEN (
                i.actual_stake <> d.actual_stake 
                OR isnull(i.winlost,0) <> isnull(d.winlost,0) 
                OR isnull(i.playercomm,0) <> isnull(d.playercomm,0)
                OR isnull(i.statusid,0) <> isnull(d.statusid,0)
                OR i.custid <> d.custid
            ) THEN
                CASE
                WHEN isnull(i.statusid,0) = 102 THEN 050 -- Void Bet

                WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 1 THEN CASE isnull(i.statusid,0) WHEN 101 THEN 020 WHEN 0 THEN 021 ELSE 0 END -- waiting -> Reject : running : something else
                 WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 0 AND isnull(i.statusid,0) > 0  -- running -> waiting/reject/cashout/Won/Lose/Draw/Refund
                    THEN CASE 
							WHEN isnull(i.statusid,0) = 1 THEN 019 -- running to waiting  
							WHEN isnull(i.statusid,0) = 101 THEN 020 -- running to reject 
                            WHEN ISNULL(i.betdaqid,0) = -2 THEN 029 -- cashout ticket							
                            ELSE 030 -- settle ticket
                        END
                WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 102 AND isnull(i.statusid,0) = 0 THEN 055 -- unvoid/recover : void -> running
                WHEN i.bettype < 19001 AND isnull(d.statusid,0) > 0 
                    THEN CASE isnull(i.statusid,0) 
                            WHEN 0 THEN CASE WHEN ISNULL(i.betdaqid,0) = -1 AND ISNULL(d.betdaqid,0) = -2 THEN 034 ELSE 032 END
                            ELSE 031 
                        END -- resettle or unsettle
                WHEN i.bettype > 20000 AND i.custid = 0 THEN 130 -- cancel transfer (custid set to zero)
                WHEN i.bettype > 20000 THEN 120 -- update transfer

                --WHEN i.bettype < 19001 AND d.custid = 0 AND i.custid > 0 THEN 055 -- recover bet
                ELSE 0 END
			WHEN i.winlostdate <> d.winlostdate THEN 002
            ELSE 001
        END,
        
        --CASE WHEN i.custid =0 THEN 'Delete ' ELSE 'Update ' END
        --  + CASE WHEN i.bettype < 19001 then 'Bet' ELSE 'Transfer' END + 
        --CASE WHEN i.custid <> 0 THEN ', from '+ d.[status] + ' to ' + i.[status] ELSE '' END
        --[Action]--vvv
        CASE 
            WHEN ( i.winlostdate <> d.winlostdate AND i.bettype NOT IN (29, 10) )
                OR (i.winlostdate > d.winlostdate AND i.bettype = 10 )
                OR (i.winlostdate > d.winlostdate AND i.bettype = 29 AND d.statusID NOT IN (0,1) )
                THEN 'Move WLD from ' 
                        + CASE 
                            WHEN ISNULL(d.winlostdate,'') = '' THEN REPLICATE(' ', 10) 
                            ELSE CONVERT(VARCHAR,d.winlostdate, 23) 
                        END
                        + ' to ' 
                        + CASE 
                            WHEN ISNULL(i.winlostdate,'') = '' THEN REPLICATE(' ', 10)
                            ELSE CONVERT(VARCHAR,i.winlostdate, 23) 
                        END                     
            ELSE '' 
        END 
		+ CASE 
			WHEN  i.actual_stake = d.actual_stake 
                AND isnull(i.winlost,0) = isnull(d.winlost,0) 
                AND isnull(i.playercomm,0) = isnull(d.playercomm,0)
                AND isnull(i.statusid,0) = isnull(d.statusid,0)
                AND i.custid = d.custid
				AND i.winlostdate <> d.winlostdate 
					THEN 'Event date was moved from ' + ISNULL(CONVERT(VARCHAR,d.winlostdate, 23),'') + ' to ' + ISNULL(CONVERT(VARCHAR,i.winlostdate, 23),'')

			ELSE ISNULL(CASE
							WHEN i.bettype < 19001 THEN 'Bet'
							WHEN i.bettype > 20000 THEN 'Transfer'
							ELSE isnull(d.[status],'running')
						END
					+
				CASE
					WHEN i.custid = 0 THEN ' cancelled, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
					WHEN i.bettype > 20000 THEN ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
					WHEN isnull(d.statusid,0) = 1 THEN
						CASE isnull(i.statusid,0)
						WHEN 0 THEN ' accepted'
						WHEN 101 THEN ' rejected'
						ELSE ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
						END
					WHEN isnull(d.statusid,0) = 0 THEN
						CASE 
							WHEN isnull(i.statusid,0) = 101 THEN ' rejected'
							WHEN isnull(i.statusid,0) = 102 THEN ' voided'
							WHEN (isnull(i.statusid,0) BETWEEN 111 AND 113) OR isnull(i.statusid,0) = 103 
								THEN CASE 
										WHEN ISNULL(i.betdaqid,0) = -2 THEN ' Cash Out, ' + isnull(d.status,' running') + ' to '  + isnull(i.status,' running')
										ELSE  ' settled, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
									END
							ELSE ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
						END
					WHEN isnull(d.statusid,0) > 0 AND isnull(d.betdaqid,0) = -2 AND isnull(i.statusid,0) = 0 
						THEN ' Cancel Cash Out, ' + isnull(d.status,'running') + ' to ' + isnull(i.status,'running')
					ELSE ' Updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
				END
			,'')
		END
        --[Action]--^^^ 
        , (isnull(i.winlost,0) - ISNULL(i.actual_stake, 0) + ISNULL(i.playercomm,0))
            - (ISNULL(d.winlost,0) - ISNULL(d.actual_stake, 0) + ISNULL(d.playercomm,0))
        ,i.matchid
        ,isnull(i.statusID,0)
        ,CASE 
			WHEN d.matchid <> i.matchid THEN 5 --change MatchID (case Move ticket)
			WHEN ISNULL(d.statusid,0) = 102 AND ISNULL(i.statusid,0) = 0 THEN 10 -- change from void to running
			WHEN ISNULL(d.statusid,0) = 112 AND ISNULL(i.statusid,0) = 102 THEN 11 -- change from won to void
            WHEN (ISNULL(i.statusID,0) BETWEEN 111 AND 113 OR ISNULL(i.statusID,0) = 103) 
                THEN CASE 
                        WHEN d.SettlementTime IS NULL THEN 1 -- first settled
                        WHEN i.SettlementTime <> d.SettlementTime 
                            THEN CASE
                                    WHEN ISNULL(d.statusID,0) = 0 THEN 2 -- change from running to settle 
                                    ELSE 3 
                                END -- re-settled: change from settle to settle
                        WHEN ISNULL(d.statusID,0) BETWEEN 111 AND 113 -- settle to settle, no change winlost
							THEN CASE
									WHEN d.winlostdate <> i.winlostdate THEN 5 -- change WinLostDate (case move Event) 
									ELSE 4
								END
                        ELSE 0 
                    END
            ELSE 0
        END -- SettlementType
        ,isnull(i.swinlost,0) as swinlost
        ,isnull(i.mwinlost,0) as mwinlost
        ,isnull(i.awinlost,0) as awinlost
        ,isnull(i.scomm,0) as scomm
        ,isnull(i.acomm,0) as acomm
        ,isnull(i.comm,0) as acomm
        ,i.modds
		,i.winlostdate
		,CASE WHEN @IsTransLog = 1 THEN i.refno ELSE NULL END
		, d.statusID
		, d.winlost
    FROM
        inserted i INNER JOIN deleted d
        ON i.transid = d.transid
    WHERE
        d.custid <> d.recommend AND
        d.custid <> d.mrecommend AND
        d.custid <> d.srecommend            
END
    
