import { AuthService } from './auth.service.js';
import { LoginDto } from './dto/login.dto.js';
export declare class AuthController {
    private readonly auth;
    constructor(auth: AuthService);
    login(dto: LoginDto): Promise<{
        accessToken: string;
        user: import("../users/users.service.js").PublicUser;
    }>;
    me(request: {
        user: {
            userId: string;
        };
    }): Promise<import("../users/users.service.js").PublicUser>;
}
