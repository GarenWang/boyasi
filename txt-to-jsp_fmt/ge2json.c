#include <stdio.h>
int main()
{
	int  username[40];
	char  userid[40];
	int started = 0;
	while (scanf("%[^,],%39[^\n]]", username, userid) == 2) 
	{
		if(started)
			printf("\n");
		else
			started = 1;
		printf("man.put(\"%s\",\"%s\");", username, userid);
	}
	return 0;
}
