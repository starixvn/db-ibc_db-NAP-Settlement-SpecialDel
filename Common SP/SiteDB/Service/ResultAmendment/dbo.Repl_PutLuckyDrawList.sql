/*<info serverAlias="DBACC-bodb02,DBAGE-bodb02,DB042-bodb02,DBTP-bodb02" executers="repl_ap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Repl_PutLuckyDrawList
	 @tvp_param TVP_ReplLuckyDrawList READONLY
AS
/*	
	Created by: 20240401@Aries
	Task: Settlement  
	DB: DBACC-bodb02,DBAGE-bodb02,DB042-bodb02,DBTP-bodb02
	
	Revisions:
		- 20240401@Aries: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]
*/
BEGIN	
	SET NOCOUNT ON

    MERGE dbo.LuckyDrawList AS l
        USING @tvp_param AS tvp
        ON h.DrawID = tvp.DrawID
        WHEN MATCHED THEN
            UPDATE 
            SET	     l.DrawID				=   tvp.DrawID   
	                ,l.matchid				=   tvp.matchid 
	                ,l.custid				=	tvp.custid 
	                ,l.TypeID				=	tvp.TypeID 
	                ,l.VerificationCode		=   tvp.VerificationCode 
	                ,l.DisplayName			=   tvp.DisplayName 
	                ,l.StatusID				=   tvp.StatusID 
	                ,l.Payout				=	tvp.Payout 
	                ,l.Currency				=   tvp.Currency 
	                ,l.Remark				=   tvp.Remark 
	                ,l.LastModifiedUserID	=	tvp.LastModifiedUserID 
	                ,l.CreatedDate			=   tvp.CreatedDate 
	                ,l.LastModifiedDate		=   tvp.LastModifiedDate 
	                ,l.ExpiredDate			=   tvp.ExpiredDate 
	                ,l.IsNotify				=   tvp.IsNotify 
	                ,l.NotifiedDate			=   tvp.NotifiedDate 
	                ,l.IsTest				=	tvp.IsTest 
	                ,l.IsLicensee			=	tvp.IsLicensee 
	                ,l.SettledDate			=	tvp.SettledDate 		
	                ,l.IsDeleted	        =   tvp.IsDeleted 
                    ,l.RepUpdateTime        =   CASE WHEN tvp.RepUpdateTime > l.RepUpdateTime THEN tvp.RepUpdateTime ELSE l.RepUpdateTime END
        WHEN NOT MATCHED THEN
            INSERT (
                 DrawID					
				,matchid				
				,custid					
				,TypeID					
				,VerificationCode		
				,DisplayName			
				,StatusID				
				,Payout					
				,Currency				
				,Remark				
				,LastModifiedUserID		
				,CreatedDate			
				,LastModifiedDate		
				,ExpiredDate			
				,IsNotify				
				,NotifiedDate			
				,IsTest					
				,IsLicensee				
				,SettledDate			
				,RepUpdateTime			
				,IsDeleted	
            ) VALUES (
                 tvp.DrawID					
				,tvp.matchid				
				,tvp.custid					
				,tvp.TypeID					
				,tvp.VerificationCode		
				,tvp.DisplayName			
				,tvp.StatusID				
				,tvp.Payout					
				,tvp.Currency				
				,tvp.Remark				
				,tvp.LastModifiedUserID		
				,tvp.CreatedDate			
				,tvp.LastModifiedDate		
				,tvp.ExpiredDate			
				,tvp.IsNotify				
				,tvp.NotifiedDate			
				,tvp.IsTest					
				,tvp.IsLicensee				
				,tvp.SettledDate			
				,tvp.RepUpdateTime			
				,tvp.IsDeleted	   
            );
END