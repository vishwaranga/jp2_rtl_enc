	
function integer bits_of;
  	input [31:0] in;
  	integer i;
  	begin
    	if(in==0)begin
    		bits_of = 1;
    	end
    	else begin
	 		i = in;
			for(bits_of=0; i>0; bits_of=bits_of+1)
			  i = i >> 1;
		end
  end
endfunction