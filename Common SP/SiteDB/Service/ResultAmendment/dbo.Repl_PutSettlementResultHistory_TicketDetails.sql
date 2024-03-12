/*<info serverAlias="DBTP-bodb02" executers="repl_ap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Repl_PutSettlementResultHistory_TicketDetails
	 @tvp_param TVP_ReplSettlementResultHistory_TicketDetails READONLY
AS
/*	
	Created by: 20231214@Aries
	Task: Settlement  
	DB: DBTP-bodb02
	
	Revisions:
		- 20231214@Aries: Result Amendment [Redmine: #196401]
*/
BEGIN	
	SET NOCOUNT ON

    MERGE dbo.SettlementResultHistory_TicketDetails AS ht
        USING @tvp_param AS tvp
        ON ht.SessionID = tvp.SessionID AND ht.Transid = tvp.Transid 
        WHEN MATCHED THEN
            UPDATE 
            SET	 ht.SessionID           = tvp.SessionID
                ,ht.SeqNo               = tvp.SeqNo
                ,ht.Transid             = tvp.Transid
                ,ht.ExtraInfo_Before    = tvp.ExtraInfo_Before
                ,ht.ExtraInfo_After     = tvp.ExtraInfo_After
                ,ht.IsDeleted           = tvp.IsDeleted
                ,ht.RepUpdateTime       = CASE WHEN tvp.RepUpdateTime > ht.RepUpdateTime THEN tvp.RepUpdateTime ELSE ht.RepUpdateTime END
        WHEN NOT MATCHED THEN
            INSERT (
                 SessionID      
                ,SeqNo        
                ,Transid			
                ,ExtraInfo_Before   
                ,ExtraInfo_After                 
                ,RepUpdateTime  
                ,IsDeleted		
            ) VALUES (
                 tvp.SessionID
                ,tvp.SeqNo
                ,tvp.Transid
                ,tvp.ExtraInfo_Before
                ,tvp.ExtraInfo_After            
                ,tvp.RepUpdateTime
                ,tvp.IsDeleted        
            );
END