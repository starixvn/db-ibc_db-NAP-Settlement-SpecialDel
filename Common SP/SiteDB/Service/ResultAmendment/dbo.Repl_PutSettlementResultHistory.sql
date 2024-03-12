/*<info serverAlias="DBTP-bodb02" executers="repl_ap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Repl_PutSettlementResultHistory
	 @tvp_param TVP_ReplSettlementResultHistory READONLY
AS
/*	
	Created by: 20231214@Aries
	Task: Settlement  
	DB: DBTP-bodb02
	
	Revisions:
		- 20231214@Aries: Result Amendment Redmine: #196401
*/
BEGIN	
	SET NOCOUNT ON

    MERGE dbo.SettlementResultHistory AS h
        USING @tvp_param AS tvp
        ON h.MatchID = tvp.MatchID AND h.SessionID = tvp.SessionID AND h.SeqNo = tvp.SeqNo 
        WHEN MATCHED THEN
            UPDATE 
            SET	 h.SessionID        = tvp.SessionID
                ,h.MatchID          = tvp.MatchID
                ,h.SeqNo            = tvp.SeqNo
                ,h.ActualResult     = tvp.ActualResult
                ,h.WrongResult      = tvp.WrongResult
                ,h.ActionType       = tvp.ActionType
                ,h.ResultType       = tvp.ResultType
                ,h.Sporttype        = tvp.Sporttype
                ,h.CreatedDate      = tvp.CreatedDate
                ,h.ModifiedDate     = tvp.ModifiedDate
                ,h.StatusID         = tvp.StatusID
                ,h.ExtraInfo        = tvp.ExtraInfo
                ,h.IsDeleted        = tvp.IsDeleted
                ,h.RepUpdateTime = CASE WHEN tvp.RepUpdateTime > h.RepUpdateTime THEN tvp.RepUpdateTime ELSE h.RepUpdateTime END
        WHEN NOT MATCHED THEN
            INSERT (
                 SessionID      
                ,MatchID        
                ,SeqNo			
                ,ActualResult   
                ,WrongResult    
                ,ActionType		
                ,ResultType     
                ,Sporttype      
                ,CreatedDate    
                ,ModifiedDate   
                ,StatusID       
                ,ExtraInfo      
                ,RepUpdateTime  
                ,IsDeleted		
            ) VALUES (
                tvp.SessionID
                ,tvp.MatchID
                ,tvp.SeqNo
                ,tvp.ActualResult
                ,tvp.WrongResult
                ,tvp.ActionType
                ,tvp.ResultType
                ,tvp.Sporttype
                ,tvp.CreatedDate
                ,tvp.ModifiedDate
                ,tvp.StatusID
                ,tvp.ExtraInfo
                ,tvp.RepUpdateTime
                ,tvp.IsDeleted        
            );
END