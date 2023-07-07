/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_BalancePending_WalletUpd]
    @BalanceWalletBefore    TVP_BalanceWalletChange READONLY
    , @BalanceWalletAfter   TVP_BalanceWalletChange READONLY
    , @ActionId             INT = 0
AS
/* 
    Created: 20170419@Bobby.nguyen  
    Task:  75500 - Implement bonus system into NAP Settlement
    DB: DBTXN/bodb02  
    Original:   

    Revisions:  
        - 20170419@Bobby.nguyen: Initial
        - 20171009@Kathy: Change column name of BonusAdjustmentTransfer [Redmine:#72789]
        - 20220511@Kathy: Force hash join when check balance [Redmine:#172624]
		- 20230523@Kathy: scaleout - credit [Redmine:#188452]

    Param's Explanation:   
        - @ActionId       : INT 
            + Keep tracing the action log which is the root cause of negative balance
*/
BEGIN
    SET NOCOUNT ON

    DECLARE @MatchId INT
    
    --FOR genneral wallet
    DECLARE @GeneralBeforeUpd   TVP_BalanceChange
    DECLARE @GeneralAfterUpd    TVP_BalanceChange
    
    --FOR bonus wallet
    DECLARE @BonusWalletChange  TVP_BalanceWalletChange
    DECLARE @BonusWalletPending TVP_BalanceWalletChange
    
    -- STORE customer bonus status
    DECLARE @tempBonusStatus    TABLE (
        custid                  INT
        , bonusID               INT
        , bonusStatus           TINYINT
    )
    
    DECLARE @tmpBalanceNegative TABLE (CustId INT, Balance MONEY)
        
    --GATHER customer bonus status
    INSERT INTO @tempBonusStatus(custid, bonusID, bonusStatus)
    SELECT bal.custid
        , bal.BonusID
        , bn.StatusID AS bonusStatus 
    FROM dbo.BonusWalletCredit AS bn WITH(NOLOCK)
        INNER JOIN @BalanceWalletBefore bal 
        ON bn.custid            = bal.custid
            AND bn.BonusID      = bal.BonusID
            AND bal.walletType  = 1 --Bonus Wallet

    BEGIN --GATHER genneral balance
        INSERT INTO @GeneralBeforeUpd (custid, balanceType, balance)
        SELECT bal.custid
            , bal.balanceType
            , SUM(balance) AS balance
        FROM (
            --CASH wallet
            SELECT bal.custid 
                , bal.balanceType
                , bal.balance
            FROM @BalanceWalletBefore bal
            WHERE bal.walletType = 2
            
            --BONUS wallet
            UNION ALL 
            SELECT bal.custid
                , bal.balanceType
                , bal.balance
            FROM @BalanceWalletBefore bal
                INNER JOIN @tempBonusStatus bn 
                    ON bal.custid       = bn.custid
                    AND bal.bonusID     = bn.bonusID
                INNER JOIN dbo.f_Set_BonusWallet_StatusSel() st
                    ON bn.bonusStatus   = st.StatusID
                    
            WHERE bal.walletType = 1
                AND st.BonusFlag = 1
        ) AS bal
        GROUP BY bal.custid, bal.balanceType
        
        --GATHER balance after
        INSERT INTO @GeneralAfterUpd (custid, balanceType, balance)
        SELECT bal.custid
            , bal.balanceType
            , SUM(balance) AS balance
        FROM (
            --CASH wallet
            SELECT bal.custid
                , bal.balanceType
                , bal.balance
            FROM @BalanceWalletAfter bal
            WHERE bal.walletType = 2
            
            --BONUS wallet
            UNION ALL
            SELECT bal.custid
                , bal.balanceType
                , bal.balance
            FROM @BalanceWalletAfter bal
                INNER JOIN @tempBonusStatus bn 
                    ON bal.custid       = bn.custid
                    AND bal.bonusID     = bn.bonusID
                INNER JOIN dbo.f_Set_BonusWallet_StatusSel() st
                    ON bn.bonusStatus   = st.StatusID
                    
            WHERE bal.walletType = 1
                AND st.BonusFlag = 1
        ) AS bal
        GROUP BY bal.custid, bal.balanceType
        
        --UPDATE genneral wallet
        IF(@@ROWCOUNT > 0)
        BEGIN
            EXEC [dbo].[NAP_Admin_BalancePendingIns]
            @BeforeUpd  = @GeneralBeforeUpd
            ,@AfterUpd  = @GeneralAfterUpd
        END
        
    END
    
    --GATER bonus wallet
    IF (EXISTS ( 
            SELECT TOP 1 1 
            FROM @tempBonusStatus st
        )
    )
    BEGIN 
        --GET diff amount from bonus wallet
        INSERT INTO @BonusWalletChange (matchid, custid, balanceType, bonusID, balance, walletType)
        SELECT a.matchid 
            , a.custid
            , 1 AS balanceType --sports
            , a.bonusID
            , (a.balance - b.balance) AS balance
            , 1 AS walletType
        FROM @BalanceWalletAfter a
            INNER HASH JOIN @BalanceWalletBefore b
            ON a.matchid            = b.matchid
                AND a.custid        = b.custid
                AND a.balanceType   = b.balanceType
                AND a.walletType    = b.walletType
                AND a.bonusID       = b.bonusID
                
        WHERE a.walletType          = 1
            AND a.bonusID           > 0

        --select '@BonusWalletChange' as [balance TVP], * FROM @BonusWalletChange
        
        --Define bonus wallet changing
        INSERT INTO @BonusWalletPending (custid, balanceType, bonusID, walletType, balance)
        SELECT custid
            , 1 AS balanceType --sports
            , bonusID
            , 1 AS walletType
            , SUM(balance) AS balance
        FROM @BonusWalletChange
        GROUP BY custid
            , bonusID
        HAVING SUM(balance) <> 0
        
        --UPDATE bonus wallet
        IF(@@ROWCOUNT > 0)
        BEGIN
            EXEC [dbo].[Dot_BalancePendingBonusIns]
            @BonusWalletChange  = @BonusWalletPending
        END
        --select '@BonusWalletPending' as [balance TVP], * FROM @BonusWalletPending
    END
    
    --Keep tracking for Adjustment Bonus transfer
    IF (EXISTS ( 
            SELECT TOP 1 1 
            FROM @tempBonusStatus bn
                INNER JOIN dbo.f_Set_BonusWallet_StatusSel() st
                ON bn.bonusStatus   = st.StatusID
            WHERE st.BonusFlag      = 2
        )
    )
    BEGIN 
        INSERT INTO dbo.BonusAdjustmentTransfer(
            LogDate
            , ExecDate
            , CustID
            , MatchID
            , BonusID
            , StatusID
            , Amount
            , isTransferred
        )
        SELECT 
            CURRENT_TIMESTAMP AS LogDate
            , CURRENT_TIMESTAMP AS ExecDate
            , bal.custid
            , bal.MatchID
            , bal.bonusID
            , bn.bonusStatus
            , bal.balance AS Amount
            , 0 AS isTransferred
        FROM @BonusWalletChange bal
            INNER JOIN @tempBonusStatus bn
                ON bal.custid   = bn.custid
                AND bal.bonusID = bn.bonusID
            INNER JOIN dbo.f_Set_BonusWallet_StatusSel() st
                ON bn.bonusStatus   = st.StatusID
        WHERE st.BonusFlag      = 2
            AND bal.balance     <> 0
    END
    
    /*
    CHECKING negative balance
    @ActionID: INT
        - 182: Inst.CAL - UNDO
        - 103: Munual.CAL - UNDO
        - 157-158: Auto Payout (HT-FT)
        - 148-149-150: Auto BetRadar (CAL-UNDO-REFUND)
        - 109-110-111: Manual Refund(ALL-HT-FT)
    */
    IF (@ActionID > 0) AND OBJECT_ID('BalanceNegative','U') IS NOT NULL
    BEGIN 
        SELECT TOP 1 @MatchId = matchid
        FROM @BalanceWalletBefore

        INSERT INTO @tmpBalanceNegative(CustId, Balance)
        SELECT
            b.custid
            ,SUM(a.balance - b.balance) AS balance
        FROM @GeneralBeforeUpd b
            INNER HASH JOIN @GeneralAfterUpd a 
                ON b.custid         = a.custid
                AND b.balanceType   = a.balanceType 
        GROUP BY b.custid               
        HAVING SUM(a.balance) < SUM(b.balance)
        
        ----
        -- Add Negative Balance into BalanceNegative table 
        ----
        INSERT INTO [dbo].[BalanceNegative] (
                [ExecDate]
                ,[MatchID]
                ,[ActionID]
                ,[GroupID]
                ,[CustID]
                ,[Balance]
                ,[StatusID]
                ,[Remark]
        )
        SELECT GETDATE()
                ,@MatchID
                ,@ActionId
                ,ISNULL(bg.GroupID,1) AS GroupID -- Negative balance defined group Id
                ,CustID
                ,Balance
                ,0
                ,NULL
        FROM @tmpBalanceNegative bal
            LEFT JOIN dbo.f_Set_NegativeBalance_ActionGroup() AS bg
            ON bg.ActionId = @ActionId
    END
END
GO
